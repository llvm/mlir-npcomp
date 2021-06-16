# -*- Python -*-
# This file is licensed under a pytorch-style license
# See frontends/pytorch/LICENSE for license information.

import typing

import torch
import torch_mlir

import typing

# RUN: %PYTHON %s | npcomp-opt | FileCheck %s

mb = torch_mlir.ModuleBuilder()


# CHECK-LABEL:   func @__torch__.prim_NumToTensor(
# CHECK-SAME:                           %[[ARG:.*]]: i64) -> !torch.tensor {
# CHECK:           %[[RET:.*]] = torch.prim.NumToTensor.Scalar %[[ARG]] : i64 -> !torch.tensor
# CHECK:           return %[[RET]] : !torch.tensor
# CHECK:         }

@mb.import_function
@torch.jit.script
def prim_NumToTensor(i: int):
    return _to_tensor(i)

# CHECK-LABEL:   func @__torch__.prim_Print(
# CHECK-SAME:                     %[[ARG:.*]]: !torch.tensor) -> !torch.none {
# CHECK:           %[[STR:.*]] = torch.constant.str "x"
# CHECK:           torch.prim.Print(%[[STR]], %[[ARG]]) : !torch.str, !torch.tensor
@mb.import_function
@torch.jit.script
def prim_Print(x):
    print("x", x)

# CHECK-LABEL:   func @__torch__.prim_RaiseException() -> !torch.none {
# CHECK:           %[[ERRORSTR:.*]] = torch.constant.str "Error"
# CHECK:           %[[NONE:.*]] = torch.prim.Uninitialized : !torch.none
# CHECK:           torch.prim.RaiseException %[[ERRORSTR]]
# CHECK:           return %[[NONE]] : !torch.none
@mb.import_function
@torch.jit.script
def prim_RaiseException():
    raise Exception("Error")

# CHECK-LABEL:   func @__torch__.prim_unchecked_cast(
# CHECK-SAME:                              %[[ARG:.*]]: !torch.optional<i64>) -> i64 {
# CHECK:           %[[NONE:.*]] = torch.constant.none
# CHECK:           %[[C3:.*]] = torch.constant.int 3 : i64
# CHECK:           %[[IS_NONE:.*]] = torch.aten.__is__ %[[ARG]], %[[NONE]] : !torch.optional<i64>, !torch.none -> !torch.bool
# CHECK:           %[[RESULT:.*]] = torch.prim.If %[[IS_NONE]] -> (i64) {
# CHECK:             torch.prim.If.yield %[[C3]] : i64
# CHECK:           } else {
# CHECK:             %[[CASTED:.*]] = torch.prim.unchecked_cast %[[ARG]] : !torch.optional<i64> -> i64
# CHECK:             torch.prim.If.yield %[[CASTED]] : i64
# CHECK:           }
# CHECK:           return %[[RESULT:.*]] : i64
@mb.import_function
@torch.jit.script
def prim_unchecked_cast(i: typing.Optional[int]):
    if i is None:
        return 3
    return i

# CHECK-LABEL:   func @__torch__.prim_TupleUnpack(
# CHECK-SAME:                     %[[ARG:.*]]: !torch.tuple<i64, i64>) -> i64 {
# CHECK:           %[[RET:.*]]:2 = torch.prim.TupleUnpack %[[ARG]] : !torch.tuple<i64, i64> -> i64, i64
# CHECK:           return %[[RET]]#0 : i64
@mb.import_function
@torch.jit.script
def prim_TupleUnpack(tup: typing.Tuple[int, int]):
    val, _ = tup
    return val

# CHECK-LABEL:   func @__torch__.prim_TupleIndex(
# CHECK-SAME:                     %[[ARG:.*]]: !torch.tuple<!torch.tensor, !torch.tensor>) -> !torch.tensor {
# CHECK:           %[[RET:.*]] = torch.prim.TupleIndex %[[ARG]], %[[IDX:.*]] : !torch.tuple<!torch.tensor, !torch.tensor>, i64 -> !torch.tensor
# CHECK:           return %[[RET]] : !torch.tensor
@mb.import_function
@torch.jit.script
def prim_TupleIndex(tup: typing.Tuple[torch.Tensor, torch.Tensor]):
    return tup[0]

# CHECK-LABEL:   func @__torch__.prim_ListUnpack(
# CHECK-SAME:                     %[[ARG:.*]]: !torch.list<i64>) -> i64 {
# CHECK:           %[[RET:.*]]:3 = torch.prim.ListUnpack %[[ARG]] : !torch.list<i64> -> i64, i64
# CHECK:           return %[[RET]]#1 : i64
@mb.import_function
@torch.jit.script
def prim_ListUnpack(l: typing.List[int]):
    _, val, _ = l
    return val

# CHECK-LABEL:   func @__torch__.prim_dtype(
# CHECK-SAME:                               %[[ARG:.*]]: !torch.tensor) -> i64 {
# CHECK:           %[[RET:.*]] = torch.prim.dtype %[[ARG]] : !torch.tensor -> i64
# CHECK:           return %[[RET]] : i64
@mb.import_function
@torch.jit.script
def prim_dtype(x):
    return x.dtype

# CHECK-LABEL:   func @__torch__.prim_layout(
# CHECK-SAME:                                %[[ARG:.*]]: !torch.tensor) -> i64 {
# CHECK:           %[[RET:.*]] = torch.prim.layout %[[ARG]] : !torch.tensor -> i64
# CHECK:           return %[[RET]] : i64
@mb.import_function
@torch.jit.script
def prim_layout(x):
    return x.layout

# CHECK-LABEL:   func @__torch__.prim_device(
# CHECK-SAME:                                %[[ARG:.*]]: !torch.tensor) -> !torch.Device {
# CHECK:           %[[RET:.*]] = torch.prim.device %[[ARG]] : !torch.tensor -> !torch.Device
# CHECK:           return %[[RET]] : !torch.Device
@mb.import_function
@torch.jit.script
def prim_device(x):
    return x.device

# CHECK-LABEL:   func @__torch__.prim_min(
# CHECK-SAME:                             %[[ARG:.*]]: i64) -> !torch.tuple<i64, i64, i64> {
# CHECK:           %[[SINGLETON:.*]] = torch.prim.ListConstruct %[[ARG]] : (i64) -> !torch.list<i64>
# CHECK:           %[[MIN1:.*]] = torch.prim.min.self_int %[[SINGLETON]] : !torch.list<i64> -> i64
# CHECK:           %[[MIN2:.*]] = torch.prim.min.int %[[ARG]], %[[ARG]] : i64, i64 -> i64
# CHECK:           %[[ARG_3_TIMES:.*]] = torch.prim.ListConstruct %[[ARG]], %[[ARG]], %[[ARG]] : (i64, i64, i64) -> !torch.list<i64>
# CHECK:           %[[MIN3:.*]] = torch.prim.min.self_int %[[ARG_3_TIMES]] : !torch.list<i64> -> i64
# CHECK:           %[[RET:.*]] = torch.prim.TupleConstruct %[[MIN1]], %[[MIN2]], %[[MIN3]] : i64, i64, i64
# CHECK:           return %[[RET]] : !torch.tuple<i64, i64, i64>
@mb.import_function
@torch.jit.script
def prim_min(x: int):
    return min(x), min(x,x), min(x, x, x)

# CHECK-LABEL:   func @__torch__.prim_max(
# CHECK-SAME:                             %[[ARG:.*]]: i64) -> !torch.tuple<i64, i64, i64> {
# CHECK:           %[[SINGLETON:.*]] = torch.prim.ListConstruct %[[ARG]] : (i64) -> !torch.list<i64>
# CHECK:           %[[MAX1:.*]] = torch.prim.max.self_int %[[SINGLETON]] : !torch.list<i64> -> i64
# CHECK:           %[[MAX2:.*]] = torch.prim.max.int %[[ARG]], %[[ARG]] : i64, i64 -> i64
# CHECK:           %[[ARG_3_TIMES:.*]] = torch.prim.ListConstruct %[[ARG]], %[[ARG]], %[[ARG]] : (i64, i64, i64) -> !torch.list<i64>
# CHECK:           %[[MAX3:.*]] = torch.prim.max.self_int %[[ARG_3_TIMES]] : !torch.list<i64> -> i64
# CHECK:           %[[RET:.*]] = torch.prim.TupleConstruct %[[MAX1]], %[[MAX2]], %[[MAX3]] : i64, i64, i64
# CHECK:           return %[[RET]] : !torch.tuple<i64, i64, i64>
@mb.import_function
@torch.jit.script
def prim_max(x: int):
    return max(x), max(x,x), max(x, x, x)

mb.module.operation.print()
print()
