# -*- Python -*-
# This file is licensed under a pytorch-style license
# See frontends/pytorch/LICENSE for license information.

import typing

import torch
import torch_mlir

# RUN: %PYTHON %s | npcomp-opt | FileCheck %s

mb = torch_mlir.ModuleBuilder()

# CHECK-LABEL:     func private @__torch__.TestModule.forward
# CHECK-SAME:        (%[[ARG0:.*]]: !torch.nn.Module<"__torch__.TestModule">, %[[ARG1:.*]]: !torch.tensor) -> !torch.tensor {
# CHECK:             %[[VAL_2:.*]] = constant @__torch__.identity : (!torch.tensor) -> !torch.tensor
# CHECK:             %[[VAL_3:.*]] = call_indirect %[[VAL_2]](%[[ARG1]]) : (!torch.tensor) -> !torch.tensor
# CHECK:             return %[[VAL_3]] : !torch.tensor
# CHECK:           }
# CHECK-LABEL:     func private @__torch__.identity
# CHECK-SAME:        (%[[ARG:.*]]: !torch.tensor) -> !torch.tensor {
# CHECK:             return %[[ARG]] : !torch.tensor
# CHECK:           }

# CHECK-LABEL:   torch.class_type @__torch__.TestModule  {
# CHECK:           torch.method "forward", @__torch__.TestModule.forward
# CHECK:         }

def identity(x):
    return x

class TestModule(torch.nn.Module):
    def __init__(self):
        super().__init__()
    def forward(self, x):
        return identity(x)

test_module = TestModule()
recursivescriptmodule = torch.jit.script(test_module)
# TODO: Automatically handle unpacking Python class RecursiveScriptModule into the underlying ScriptModule.
mb.import_module(recursivescriptmodule._c)
mb.module.operation.print()
