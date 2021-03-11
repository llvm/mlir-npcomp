//===- node_importer.cpp --------------------------------------------------===//
//
// This file is licensed under a pytorch-style license
// See frontends/pytorch/LICENSE for license information.
//
//===----------------------------------------------------------------------===//

#include "node_importer.h"

#include <unordered_map>

#include "mlir_utils.h"
#include "op_builder.h"

#include "mlir-c/BuiltinAttributes.h"
#include "mlir-c/BuiltinTypes.h"
#include "mlir-c/Diagnostics.h"
#include "npcomp-c/Types.h"

namespace py = pybind11;
using namespace torch_mlir;

using Value = torch::jit::Value;
using Block = torch::jit::Block;
using Node = torch::jit::Node;

namespace {
class NodeImporter {
public:
  NodeImporter(MlirContext context) : context(context) {}

  void importNode(Node *node, MlirBlock appendToBlock);
  MlirBlock importBlock(Block *jitBlock, CreateTerminatorFn createTerminator);

private:
  void importPrimNode(Node *node, MlirBlock appendToBlock);
  void importKernelCall(Node *node, MlirBlock appendToBlock);

  MlirBlock createBlockFor(Block *jitBlock);
  void mapValue(Value *jitValue, MlirValue value);
  void mapResults(Node *node, MlirOperation operation);
  MlirValue lookupMappedValue(Value *jitValue);
  std::vector<MlirValue> lookupMappedValues(c10::ArrayRef<Value *> values);

  MlirContext context;
  std::unordered_map<Value *, MlirValue> valueMap;
};
} // namespace

void NodeImporter::importPrimNode(Node *node, MlirBlock appendToBlock) {
  TypeMapper typeMapper(context);
  MlirLocation loc = getMlirLocationFromNode(context, node);
  auto kind = node->kind();

  auto createAndMapTrivialNode = [&](Node *node, const std::string &opName) {
    MlirOperation operation =
        createMlirOperationAtEnd(appendToBlock, opName, loc,
                                 getMlirTypesFromValues(loc, node->outputs()),
                                 lookupMappedValues(node->inputs()));
    mapResults(node, operation);
  };
  auto createAndMapNodeWithAttribute = [&](Node *node,
                                           const std::string &opName,
                                           const std::string &attrName,
                                           MlirAttribute attr) {
    MlirOperation operation =
        createMlirOperationAtEnd(appendToBlock, opName, loc,
                                 getMlirTypesFromValues(loc, node->outputs()),
                                 lookupMappedValues(node->inputs()),
                                 toMlirNamedAttribute(attrName.c_str(), attr));
    mapResults(node, operation);
  };
  switch (kind) {
  case c10::prim::TupleIndex:
  case c10::prim::TupleUnpack:
  case c10::prim::ListUnpack:
  case c10::prim::dtype:
  case c10::prim::unchecked_cast:
  case c10::prim::Uninitialized:
  case c10::prim::RaiseException:
  case c10::prim::Print:
  case c10::prim::NumToTensor: {
    createAndMapTrivialNode(node,
                            "torch.prim." + std::string(kind.toUnqualString()));
    return;
  }
  case c10::prim::ListConstruct: {
    createAndMapTrivialNode(node, "basicpy.build_list");
    return;
  }
  case c10::prim::TupleConstruct: {
    createAndMapTrivialNode(node, "basicpy.build_tuple");
    return;
  }
  case c10::prim::GetAttr:
  case c10::prim::SetAttr:
  case c10::prim::CallMethod: {
    createAndMapNodeWithAttribute(
        node, "torch.prim." + std::string(kind.toUnqualString()), "name",
        importAttribute(loc, node, c10::attr::name));
    return;
  }
  }

  if (kind == c10::prim::Constant) {
    auto output = node->output();
    MlirOperation op;
    OpBuilder builder(context);
    if (output->type()->cast<c10::NoneType>()) {
      op = builder.createNoneConstant(loc);
    } else if (output->type()->cast<c10::BoolType>()) {
      op = builder.createBoolConstant(
          loc, static_cast<bool>(node->i(c10::attr::value)));
    } else if (output->type()->cast<c10::StringType>()) {
      // TODO: Are TorchScript strings bytes or str technically?
      // For now, model it as bytes to avoid pledging more than we currently
      // model (e.g. no unicode, etc.).
      op = builder.createBytesConstant(loc, node->s(c10::attr::value));
    } else if (auto functionType = output->type()->cast<c10::FunctionType>()) {
      torch::jit::Function *function = functionType->function();
      const std::string &symName = function->qualname().qualifiedName();
      op = createMlirOperation(
          "std.constant", loc,
          getFunctionTypeFromSchema(context, function->getSchema()),
          toMlirNamedAttribute(
              "value",
              mlirFlatSymbolRefAttrGet(context, toMlirStringRef(symName))));
    } else {
      MlirAttribute valueAttr = importAttribute(loc, node, c10::attr::value);
      op = builder.createStdConstant(loc, valueAttr);
    }
    mlirBlockAppendOwnedOperation(appendToBlock, op);
    mapResults(node, op);
    return;
  }

  if (kind == c10::prim::Loop) {
    std::vector<MlirType> resultTypes =
        getMlirTypesFromValues(loc, node->outputs());
    MlirOperation operation = createMlirOperationAtEnd(
        appendToBlock, "torch.prim.Loop", loc, resultTypes,
        lookupMappedValues(node->inputs().slice(0, 2)),
        derefineValues(lookupMappedValues(node->inputs().slice(2)), resultTypes,
                       loc, appendToBlock),
        mlirRegionCreate());
    mapResults(node, operation);
    std::vector<MlirType> terminatorOperandTypes = {npcompBoolTypeGet(context)};
    terminatorOperandTypes.insert(terminatorOperandTypes.end(),
                                  resultTypes.begin(), resultTypes.end());
    auto createTerminator = [&](c10::ArrayRef<MlirValue> yieldedValues,
                                MlirBlock appendToBlock) {
      createMlirOperationAtEnd(appendToBlock, "torch.prim.Loop.condition", loc,
                               derefineValues(yieldedValues,
                                              terminatorOperandTypes, loc,
                                              appendToBlock));
    };
    mlirRegionAppendOwnedBlock(
        mlirOperationGetRegion(operation, 0),
        importBlock(node->blocks()[0], createTerminator));
    return;
  }

  if (kind == c10::prim::If) {
    // TorchScript will already have an explicit op to determine truthiness. So
    // all we need to do here is launder !basicpy.BoolType to i1 for `scf.if`.
    MlirOperation pred = createMlirOperationAtEnd(
        appendToBlock, "basicpy.bool_cast", loc, mlirIntegerTypeGet(context, 1),
        lookupMappedValue(node->input()));
    std::vector<MlirType> resultTypes =
        getMlirTypesFromValues(loc, node->outputs());
    MlirOperation operation = createMlirOperationAtEnd(
        appendToBlock, "scf.if", loc, mlirOperationGetResult(pred, 0),
        resultTypes, mlirRegionCreate(), mlirRegionCreate());
    mapResults(node, operation);
    auto createTerminator =
        [&](c10::ArrayRef<MlirValue> yieldedValues, MlirBlock appendToBlock) {
          createMlirOperationAtEnd(
              appendToBlock, "scf.yield", loc,
              derefineValues(yieldedValues, resultTypes, loc, appendToBlock));
        };
    mlirRegionAppendOwnedBlock(
        mlirOperationGetRegion(operation, 0),
        importBlock(node->blocks()[0], createTerminator));
    mlirRegionAppendOwnedBlock(
        mlirOperationGetRegion(operation, 1),
        importBlock(node->blocks()[1], createTerminator));
    return;
  }

  if (kind == c10::prim::CallFunction) {
    auto functionType = node->input(0)->type()->cast<c10::FunctionType>();
    torch::jit::Block *calleeEntryBlock =
        functionType->function()->graph()->block();
    auto expectedTypes = c10::fmap(calleeEntryBlock->inputs(), [&](Value *v) {
      return typeMapper.mapFromTorchType(loc, v->type());
    });
    MlirOperation operation = createMlirOperationAtEnd(
        appendToBlock, "std.call_indirect", loc,
        getMlirTypesFromValues(loc, node->outputs()),
        lookupMappedValue(node->input(0)),
        derefineValues(lookupMappedValues(node->inputs().slice(1)),
                       expectedTypes, loc, appendToBlock));
    mapResults(node, operation);
    return;
  }

  // Unhandled.
  {
    std::stringstream msg;
    msg << "unhandled prim operation: ";
    node->print(msg, 0, nullptr);
    mlirEmitError(getMlirLocationFromNode(context, node), msg.str().c_str());
    throw mlir_diagnostic_emitted();
  }
}

void NodeImporter::importKernelCall(Node *node, MlirBlock appendToBlock) {
  TypeMapper typeMapper(context);
  MlirLocation loc = getMlirLocationFromNode(context, node);
  KernelCallBuilder kcb(context, loc, node->kind().toQualString(),
                        node->schema());
  for (MlirValue value : lookupMappedValues(node->inputs())) {
    kcb.addOperand(value);
  }
  for (MlirType type : getMlirTypesFromValues(loc, node->outputs())) {
    kcb.addResultType(type);
  }
  MlirOperation op = kcb.create();
  mlirBlockAppendOwnedOperation(appendToBlock, op);
  mapResults(node, op);
}

void NodeImporter::importNode(Node *node, MlirBlock appendToBlock) {
  if (node->kind().ns() == c10::namespaces::prim) {
    importPrimNode(node, appendToBlock);
    return;
  }
  if (node->maybeSchema()) {
    importKernelCall(node, appendToBlock);
    return;
  }

  {
    std::stringstream msg;
    msg << "unhandled: generic operation: ";
    node->print(msg, 0, nullptr);
    mlirEmitError(getMlirLocationFromNode(context, node), msg.str().c_str());
    throw mlir_diagnostic_emitted();
  }
}

MlirBlock NodeImporter::importBlock(Block *jitBlock,
                                    CreateTerminatorFn createTerminator) {
  MlirBlock block = createBlockFor(jitBlock);
  for (Node *node : jitBlock->nodes()) {
    importNode(node, block);
  }
  Node *returnNode = jitBlock->return_node();
  createTerminator(lookupMappedValues(returnNode->inputs()), block);
  return block;
}

MlirBlock NodeImporter::createBlockFor(Block *jitBlock) {
  Node *paramNode = jitBlock->param_node();
  MlirLocation loc = getMlirLocationFromNode(context, paramNode);
  std::vector<MlirType> blockArgTypes =
      getMlirTypesFromValues(loc, paramNode->outputs());
  MlirBlock block = mlirBlockCreate(blockArgTypes.size(), blockArgTypes.data());
  for (int i = 0, e = mlirBlockGetNumArguments(block); i < e; i++) {
    Value *jitValue = paramNode->outputs()[i];
    MlirValue value = mlirBlockGetArgument(block, i);
    mapValue(jitValue, value);
  }
  return block;
}

void NodeImporter::mapValue(Value *jitValue, MlirValue value) {
  auto it = valueMap.find(jitValue);
  (void)it;
  assert(it == valueMap.end() && "jitValue has already been mapped");
  valueMap[jitValue] = value;
}
void NodeImporter::mapResults(Node *node, MlirOperation operation) {
  assert(node->outputs().size() ==
         (size_t)mlirOperationGetNumResults(operation));
  for (int i = 0, e = node->outputs().size(); i < e; i++) {
    mapValue(node->outputs()[i], mlirOperationGetResult(operation, i));
  }
}
MlirValue NodeImporter::lookupMappedValue(Value *jitValue) {
  auto it = valueMap.find(jitValue);
  assert(it != valueMap.end() &&
         "trying to get mapping for jitValue that is not mapped yet!");
  return it->second;
}
std::vector<MlirValue>
NodeImporter::lookupMappedValues(c10::ArrayRef<Value *> values) {
  std::vector<MlirValue> ret;
  for (Value *value : values) {
    ret.push_back(lookupMappedValue(value));
  }
  return ret;
}

MlirBlock torch_mlir::importBlock(MlirContext context, Block *jitBlock,
                                  CreateTerminatorFn createTerminator) {
  NodeImporter importer(context);
  return importer.importBlock(jitBlock, createTerminator);
}
