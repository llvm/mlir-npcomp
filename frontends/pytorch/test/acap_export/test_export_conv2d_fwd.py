# -*- Python -*-
# This file is licensed under a pytorch-style license
# See frontends/pytorch/LICENSE for license information.

import torch
import torch_mlir

# RUN: %PYTHON %s | npcomp-opt | FileCheck %s

mb = torch_mlir.ModuleBuilder()

N = 3
Cin = 16
Cout = 4
w = 10
h = 10

model = torch.nn.Conv2d(Cin, Cout, (3,3))
ref_model = torch.nn.Conv2d(Cin, Cout, (3,3))

ref_model.weight.data = model.weight.clone()
ref_model.bias.data = model.bias.clone()

softmax = torch.nn.LogSoftmax(dim=1)
loss = torch.nn.NLLLoss()

tensor = torch.randn(N, Cin, h, w)

with mb.capture_function("conv2d_fwd", [tensor]) as f:
  result = model(tensor)
  f.returns([result])

# NOTE: Assertions have been autogenerated by utils/generate-test-checks.py
# CHECK-LABEL:   func @conv2d_fwd(
# CHECK-SAME:                     %[[VAL_0:.*]]: !torch.tensor<[3,16,10,10],f32>) -> !torch.tensor<[3,4,8,8],f32> {
# CHECK:           %[[VAL_1:.*]] = torch.constant.int 1
# CHECK:           %[[VAL_2:.*]] = torch.constant.int 1
# CHECK:           %[[VAL_3:.*]] = torch.constant.int 0
# CHECK:           %[[VAL_4:.*]] = torch.constant.int 0
# CHECK:           %[[VAL_5:.*]] = torch.constant.int 1
# CHECK:           %[[VAL_6:.*]] = torch.constant.int 1
# CHECK:           %[[VAL_7:.*]] = torch.constant.bool false
# CHECK:           %[[VAL_8:.*]] = torch.constant.int 0
# CHECK:           %[[VAL_9:.*]] = torch.constant.int 0
# CHECK:           %[[VAL_10:.*]] = torch.constant.int 1
# CHECK:           %[[VAL_11:.*]] = torch.tensor.literal(opaque<"_", "0xDEADBEEF"> : tensor<4x16x3x3xf32>) : !torch.tensor<[4,16,3,3],f32>
# CHECK:           %[[VAL_12:.*]] = torch.tensor.literal(opaque<"_", "0xDEADBEEF"> : tensor<4xf32>) : !torch.tensor<[4],f32>
# CHECK:           %[[VAL_13:.*]] = torch.prim.ListConstruct %[[VAL_1]], %[[VAL_2]] : (!torch.int, !torch.int) -> !torch.list<!torch.int>
# CHECK:           %[[VAL_14:.*]] = torch.prim.ListConstruct %[[VAL_3]], %[[VAL_4]] : (!torch.int, !torch.int) -> !torch.list<!torch.int>
# CHECK:           %[[VAL_15:.*]] = torch.prim.ListConstruct %[[VAL_5]], %[[VAL_6]] : (!torch.int, !torch.int) -> !torch.list<!torch.int>
# CHECK:           %[[VAL_16:.*]] = torch.prim.ListConstruct %[[VAL_8]], %[[VAL_9]] : (!torch.int, !torch.int) -> !torch.list<!torch.int>
# CHECK:           %[[VAL_17:.*]] = torch.operator "aten.convolution"(%[[VAL_0]], %[[VAL_11]], %[[VAL_12]], %[[VAL_13]], %[[VAL_14]], %[[VAL_15]], %[[VAL_7]], %[[VAL_16]], %[[VAL_10]]) : (!torch.tensor<[3,16,10,10],f32>, !torch.tensor<[4,16,3,3],f32>, !torch.tensor<[4],f32>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.bool, !torch.list<!torch.int>, !torch.int) -> !torch.tensor<[3,4,8,8],f32>
# CHECK:           return %[[VAL_17]] : !torch.tensor<[3,4,8,8],f32>
# CHECK:         }

mb.module.operation.print(large_elements_limit=2)
