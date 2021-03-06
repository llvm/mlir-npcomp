# -*- Python -*-
# This file is licensed under a pytorch-style license
# See frontends/pytorch/LICENSE for license information.

import torch
import torch_mlir

# RUN: %PYTHON %s | npcomp-opt | FileCheck %s

mb = torch_mlir.ModuleBuilder()

# Note: The "if without else" case is handled by yielding None from the
# else branch and making all defined values optional, so no special handling
# is needed.

# CHECK-LABEL: @__torch__.prim_If(
# CHECK-SAME:           %[[B:.*]]: !torch.bool,
# CHECK-SAME:           %[[I:.*]]: !torch.int) -> !torch.int {
@mb.import_function
@torch.jit.script
def prim_If(b: bool, i: int):
    # CHECK:           %[[RES:.*]] = torch.prim.If %[[B]] -> (!torch.int) {
    # CHECK:             %[[ADD:.*]] = torch.aten.add.int %[[I]], %[[I]]
    # CHECK:             torch.prim.If.yield %[[ADD]] : !torch.int
    # CHECK:           } else {
    # CHECK:             %[[MUL:.*]] = torch.aten.mul.int %[[I]], %[[I]]
    # CHECK:             torch.prim.If.yield %[[MUL]] : !torch.int
    # CHECK:           }
    # CHECK:           return %[[RES:.*]] : !torch.int
    if b:
        return i + i
    else:
        return i * i

# CHECK-LABEL:   func @__torch__.prim_If_derefine(
# CHECK-SAME:                           %[[B:.*]]: !torch.bool,
# CHECK-SAME:                           %[[I:.*]]: !torch.int) -> !torch.optional<!torch.int> {
# CHECK:           %[[NONE:.*]] = torch.constant.none
# CHECK:           %[[RES:.*]] = torch.prim.If %[[B]] -> (!torch.optional<!torch.int>) {
# CHECK:             %[[NONE_DEREFINED:.*]] = torch.derefine %[[NONE]] : !torch.none to !torch.optional<!torch.int>
# CHECK:             torch.prim.If.yield %[[NONE_DEREFINED]] : !torch.optional<!torch.int>
# CHECK:           } else {
# CHECK:             %[[I_DEREFINED:.*]] = torch.derefine %[[I]] : !torch.int to !torch.optional<!torch.int>
# CHECK:             torch.prim.If.yield %[[I_DEREFINED]] : !torch.optional<!torch.int>
# CHECK:           }
# CHECK:           return %[[RES:.*]] : !torch.optional<!torch.int>
@mb.import_function
@torch.jit.script
def prim_If_derefine(b: bool, i: int):
    if b:
        return None
    return i

mb.module.operation.print()
print()
