//===- RecognizeTorchFallbackPass.cpp ---------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "npcomp/RefBackend/RefBackend.h"
#include "PassDetail.h"

#include "mlir/IR/PatternMatch.h"
#include "mlir/Dialect/Shape/IR/Shape.h"
#include "mlir/Dialect/StandardOps/IR/Ops.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"
#include "npcomp/Dialect/Basicpy/IR/BasicpyDialect.h"
#include "npcomp/Dialect/Basicpy/IR/BasicpyOps.h"
#include "npcomp/Dialect/Numpy/IR/NumpyDialect.h"
#include "npcomp/Dialect/Numpy/IR/NumpyOps.h"
#include "npcomp/Dialect/Refback/IR/RefbackOps.h"
#include "npcomp/Dialect/Refback/IR/RefbackDialect.h"
#include "npcomp/Dialect/Torch/IR/OpInterfaces.h"
#include "npcomp/Dialect/Torch/IR/TorchOps.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "recognize-torch-fallback"

using namespace mlir;
using namespace mlir::NPCOMP;
using namespace mlir::NPCOMP::refback;
using namespace mlir::NPCOMP::Basicpy;
using namespace mlir::NPCOMP::Torch;

namespace {

class EncapsulateKernelCallOpPattern : public OpRewritePattern<Torch::KernelCallOp> {
public:
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(Torch::KernelCallOp kernelCall,
                                PatternRewriter &rewriter) const override {
    Operation *kcOp = kernelCall.getOperation();
    // Do not match kernel-calls that already sit in a Torch fallback region.
    if (isa<TorchFallbackOp>(kcOp->getParentOp())) {
      return failure();
    }
    // Check for defining ops that are not supported and signal match failure.
    for (auto arg : kernelCall.args()) {
      Operation *op = arg.getDefiningOp();
      if (op && !isa<ConstantOp,BuildListOp>(op)) {
        return failure();
      }
    }
    // New Torch fallback region.
    auto torchfb = rewriter.create<refback::TorchFallbackOp>(
        kernelCall.getLoc(), kernelCall.results().getType(), kernelCall.args());
    // Build the region body.
    rewriter.createBlock(&torchfb.doRegion());
    SmallVector<Value, 6> encapArgs;
    for (auto arg : kernelCall.args()) {
      Operation *op = arg.getDefiningOp();
      if (op) {
        auto encapOp = rewriter.clone(*op);
        encapArgs.push_back(encapOp->getResult(0));
      }
      else {
        encapArgs.push_back(arg);
      }
    }
    auto encapKcOp = rewriter.create<Torch::KernelCallOp>(kernelCall.getLoc(),
        kernelCall.results().getType(),
        kernelCall.kernelName(),
        ValueRange(encapArgs),
        kernelCall.sigArgTypes(),
        kernelCall.sigRetTypes(),
        kernelCall.sigIsVararg(),
        kernelCall.sigIsVarret(),
        kernelCall.sigIsMutable()
        );
    rewriter.create<refback::TorchFallbackYieldOp>(kernelCall.getLoc(), encapKcOp->getResults());
    // Finally, replace with the results of the shape.assuming
    rewriter.replaceOp(kernelCall, torchfb.getResults());
    return success();
  }
};

class RecognizeTorchFallbackPass
    : public RecognizeTorchFallbackBase<RecognizeTorchFallbackPass> {
  void getDependentDialects(DialectRegistry &registry) const override {
    registry.insert<RefbackDialect>();
  }

  void runOnOperation() override {
    auto func = getOperation();
    auto &context = getContext();
    OwningRewritePatternList patterns(&context);
    patterns.insert<EncapsulateKernelCallOpPattern>(&context);
    if (failed(
          applyPatternsAndFoldGreedily(func, std::move(patterns))))
      signalPassFailure();
  }
};

} // namespace

std::unique_ptr<OperationPass<FuncOp>>
mlir::NPCOMP::createRecognizeTorchFallbackPass() {
  return std::make_unique<RecognizeTorchFallbackPass>();
}