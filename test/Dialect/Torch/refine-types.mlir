// RUN: npcomp-opt -torch-refine-types -split-input-file %s | FileCheck %s

// CHECK-LABEL:   func @f(
// CHECK-SAME:            %[[ARG:.*]]: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
// CHECK:           %[[SHAPED:.*]] = torch.tensor_static_info_cast %[[ARG]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor<[2,3,?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[SHAPED]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
  %0 = torch.tensor_static_info_cast %arg0 : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
  return %0 : !torch.vtensor
}

// -----

// CHECK-LABEL:   func @f(
// CHECK-SAME:            %[[ARG:.*]]: !torch.vtensor<[2,3,?],f32>) -> !torch.tensor {
// CHECK:           %[[CASTED:.*]] = torch.tensor_static_info_cast %[[ARG]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor<[2,3,?],f32>
// CHECK:           %[[NONVAL_TENSOR:.*]] = torch.copy.to_tensor %[[CASTED]] : !torch.tensor<[2,3,?],f32>
// CHECK:           %[[ERASED:.*]] = torch.tensor_static_info_cast %[[NONVAL_TENSOR]] : !torch.tensor<[2,3,?],f32> to !torch.tensor
// CHECK:           return %[[ERASED]] : !torch.tensor
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> !torch.tensor {
  %0 = torch.tensor_static_info_cast %arg0 : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
  %1 = torch.copy.to_tensor %0 : !torch.tensor
  return %1 : !torch.tensor
}

// -----

// CHECK-LABEL:   func @f(
// CHECK-SAME:            %[[ARG:.*]]: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
// CHECK:           %[[SHAPED:.*]] = torch.aten.tanh %[[ARG]] : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[SHAPED]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
  %1 = torch.aten.tanh %arg0 : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor
  return %1 : !torch.vtensor
}

// -----

// CHECK-LABEL:   func @f(
// CHECK-SAME:            %[[LHS:.*]]: !torch.vtensor<[2,?],f32>,
// CHECK-SAME:            %[[RHS:.*]]: !torch.vtensor<[?,?],f32>) -> !torch.vtensor {
// CHECK:           %[[MM:.*]] = torch.aten.mm %[[LHS]], %[[RHS]] : !torch.vtensor<[2,?],f32>, !torch.vtensor<[?,?],f32> -> !torch.vtensor<[?,?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[MM]] : !torch.vtensor<[?,?],f32> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @f(%arg0: !torch.vtensor<[2,?],f32>, %arg1: !torch.vtensor<[?,?],f32>) -> !torch.vtensor {
  %1 = torch.aten.mm %arg0, %arg1 : !torch.vtensor<[2,?],f32>, !torch.vtensor<[?,?],f32> -> !torch.vtensor
  return %1 : !torch.vtensor
}

// -----

// CHECK-LABEL:   func @f(
// CHECK-SAME:            %[[INPUT:.*]]: !torch.vtensor<[?,3],f32>,
// CHECK-SAME:            %[[WEIGHT:.*]]: !torch.vtensor<[5,3],f32>,
// CHECK-SAME:            %[[BIAS:.*]]: !torch.vtensor<[5],f32>) -> !torch.vtensor {
// CHECK:           %[[LINEAR:.*]] = torch.aten.linear %[[INPUT]], %[[WEIGHT]], %[[BIAS]] : !torch.vtensor<[?,3],f32>, !torch.vtensor<[5,3],f32>, !torch.vtensor<[5],f32> -> !torch.vtensor<[?,?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[LINEAR]] : !torch.vtensor<[?,?],f32> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @f(%arg0: !torch.vtensor<[?,3],f32>, %arg1: !torch.vtensor<[5,3],f32>, %arg2: !torch.vtensor<[5],f32>) -> !torch.vtensor {
  %1 = torch.aten.linear %arg0, %arg1, %arg2 : !torch.vtensor<[?,3],f32>, !torch.vtensor<[5,3],f32>, !torch.vtensor<[5],f32> -> !torch.vtensor
  return %1 : !torch.vtensor
}

// -----

// CHECK-LABEL: func @f
// CHECK:           %[[CONV2D:.*]] = torch.aten.conv2d{{.*}} -> !torch.vtensor<[?,?,?,?],unk>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[CONV2D]] : !torch.vtensor<[?,?,?,?],unk> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @f(%arg0:!torch.vtensor, %arg1:!torch.vtensor, %arg2:!torch.vtensor) ->!torch.vtensor {
  %int0 = torch.constant.int 0
  %int1 = torch.constant.int 1
  %0 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %1 = torch.prim.ListConstruct %int0, %int0 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %2 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %3 = torch.aten.conv2d %arg0, %arg1, %arg2, %0, %1, %2, %int1 : !torch.vtensor, !torch.vtensor, !torch.vtensor, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.int ->!torch.vtensor
  return %3 :!torch.vtensor
}

// CHECK-LABEL: func @g
// CHECK:           %[[CONV2D:.*]] = torch.aten.conv2d{{.*}} -> !torch.vtensor<[?,?,?,?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[CONV2D]] : !torch.vtensor<[?,?,?,?],f32> to !torch.vtensor
// CHECK:           return %[[SHAPE_ERASED]] : !torch.vtensor
func @g(%arg0:!torch.vtensor<*,f32>, %arg1:!torch.vtensor<*,f32>, %arg2:!torch.vtensor<*,f32>) ->!torch.vtensor {
  %int0 = torch.constant.int 0
  %int1 = torch.constant.int 1
  %0 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %1 = torch.prim.ListConstruct %int0, %int0 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %2 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %3 = torch.aten.conv2d %arg0, %arg1, %arg2, %0, %1, %2, %int1 : !torch.vtensor<*,f32>, !torch.vtensor<*,f32>, !torch.vtensor<*,f32>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.int ->!torch.vtensor
  return %3 :!torch.vtensor
}

// -----

// CHECK-LABEL: func @f
func @f(%arg0: !torch.vtensor<[?,?,?,?],f32>) -> !torch.vtensor {
  %int1 = torch.constant.int 1
  %int3 = torch.constant.int 3
  %int2 = torch.constant.int 2
  %bool_false = torch.constant.bool false
  %21 = torch.prim.ListConstruct %int3, %int3 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %22 = torch.prim.ListConstruct %int2, %int2 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %23 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  %24 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  // CHECK: torch.aten.max_pool2d{{.*}} -> !torch.vtensor<[?,?,?,?],f32>
  %27 = torch.aten.max_pool2d %arg0, %21, %22, %23, %24, %bool_false : !torch.vtensor<[?,?,?,?],f32>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.list<!torch.int>, !torch.bool -> !torch.vtensor
  return %27 : !torch.vtensor
}

// -----

// CHECK-LABEL: func @f
func @f(%arg0: !torch.vtensor<[?,?,?,?],f32>) -> !torch.vtensor {
  %int1 = torch.constant.int 1
  %0 = torch.prim.ListConstruct %int1, %int1 : (!torch.int, !torch.int) -> !torch.list<!torch.int>
  // CHECK: torch.aten.adaptive_avg_pool2d{{.*}} -> !torch.vtensor<[?,?,?,?],f32>
  %1 = torch.aten.adaptive_avg_pool2d %arg0, %0 : !torch.vtensor<[?,?,?,?],f32>, !torch.list<!torch.int> -> !torch.vtensor
  return %1 : !torch.vtensor
}

// -----

// Also test cast insertion for array types.
// CHECK-LABEL:   func @flatten_all(
// CHECK:           %[[FLATTENED:.*]] = torch.aten.flatten.using_ints{{.*}}-> !torch.tensor<[?],f32>
// CHECK:           %[[SHAPE_ERASED:.*]] = torch.tensor_static_info_cast %[[FLATTENED]] : !torch.tensor<[?],f32> to !torch.tensor
// CHECK:           return %[[SHAPE_ERASED]]
func @flatten_all(%arg0: !torch.tensor<[3,2,?,5],f32>) -> !torch.tensor {
  %end = torch.constant.int -1
  %start = torch.constant.int 0
  %0 = torch.aten.flatten.using_ints %arg0, %start, %end : !torch.tensor<[3,2,?,5],f32>, !torch.int, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @flatten_some(
// CHECK:           torch.aten.flatten.using_ints{{.*}}-> !torch.tensor<[3,?,5],f32>
func @flatten_some(%arg0: !torch.tensor<[3,2,?,5],f32>) -> !torch.tensor {
  %end = torch.constant.int -2
  %start = torch.constant.int 1
  %0 = torch.aten.flatten.using_ints %arg0, %start, %end : !torch.tensor<[3,2,?,5],f32>, !torch.int, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @flatten_rank0(
// CHECK:           torch.aten.flatten.using_ints{{.*}}-> !torch.tensor<[?],f32>
func @flatten_rank0(%arg0: !torch.tensor<[],f32>) -> !torch.tensor {
  %end = torch.constant.int -1
  %start = torch.constant.int 0
  %0 = torch.aten.flatten.using_ints %arg0, %start, %end : !torch.tensor<[],f32>, !torch.int, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// -----

// CHECK-LABEL:   func @torch.aten.unsqueeze$basic(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<[1],f32>
func @torch.aten.unsqueeze$basic(%arg0: !torch.tensor<[],f32>) -> !torch.tensor {
  %int0 = torch.constant.int 0
  %0 = torch.aten.unsqueeze %arg0, %int0 : !torch.tensor<[],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$basic_negative(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<[1],f32>
func @torch.aten.unsqueeze$basic_negative(%arg0: !torch.tensor<[],f32>) -> !torch.tensor {
  %int-1 = torch.constant.int -1
  %0 = torch.aten.unsqueeze %arg0, %int-1 : !torch.tensor<[],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$invalid(
// CHECK:           torch.aten.unsqueeze {{.*}} !torch.tensor<*,f32>
func @torch.aten.unsqueeze$invalid(%arg0: !torch.tensor<[],f32>) -> !torch.tensor {
  %int1 = torch.constant.int 1
  %0 = torch.aten.unsqueeze %arg0, %int1 : !torch.tensor<[],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$invalid_negative(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<*,f32>
func @torch.aten.unsqueeze$invalid_negative(%arg0: !torch.tensor<[],f32>) -> !torch.tensor {
  %int-2 = torch.constant.int -2
  %0 = torch.aten.unsqueeze %arg0, %int-2 : !torch.tensor<[],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$higher_rank_front(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<[1,2,3,4],f32>
func @torch.aten.unsqueeze$higher_rank_front(%arg0: !torch.tensor<[2,3,4],f32>) -> !torch.tensor {
  %int0 = torch.constant.int 0
  %0 = torch.aten.unsqueeze %arg0, %int0 : !torch.tensor<[2,3,4],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$higher_rank_back(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<[2,3,4,1],f32>
func @torch.aten.unsqueeze$higher_rank_back(%arg0: !torch.tensor<[2,3,4],f32>) -> !torch.tensor {
  %int-1 = torch.constant.int -1
  %0 = torch.aten.unsqueeze %arg0, %int-1 : !torch.tensor<[2,3,4],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$higher_rank_middle(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<[2,3,1,4],f32>
func @torch.aten.unsqueeze$higher_rank_middle(%arg0: !torch.tensor<[2,3,4],f32>) -> !torch.tensor {
  %int2 = torch.constant.int 2
  %0 = torch.aten.unsqueeze %arg0, %int2 : !torch.tensor<[2,3,4],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// CHECK-LABEL:   func @torch.aten.unsqueeze$unknown_position(
// CHECK:           torch.aten.unsqueeze {{.*}} -> !torch.tensor<*,f32>
func @torch.aten.unsqueeze$unknown_position(%arg0: !torch.tensor<[2],f32>, %arg1: !torch.int) -> !torch.tensor {
  %0 = torch.aten.unsqueeze %arg0, %arg1 : !torch.tensor<[2],f32>, !torch.int -> !torch.tensor
  return %0 : !torch.tensor
}

// -----

// CHECK-LABEL: func @f
func @f(%arg0: !torch.vtensor<[4,6,3],f32>, %arg1: !torch.vtensor<[1,1,3],f32>, %arg2: !torch.vtensor<[?,3],f32>) {
  %int1 = torch.constant.int 1
  // CHECK: torch.aten.add{{.*}} -> !torch.vtensor<[?,?,?],f32>
  %0 = torch.aten.add.Tensor %arg0, %arg1, %int1 : !torch.vtensor<[4,6,3],f32>, !torch.vtensor<[1,1,3],f32>, !torch.int -> !torch.vtensor
  // CHECK: torch.aten.add{{.*}} -> !torch.vtensor<[?,?,?],f32>
  %1 = torch.aten.add.Tensor %arg0, %arg2, %int1 : !torch.vtensor<[4,6,3],f32>, !torch.vtensor<[?,3],f32>, !torch.int -> !torch.vtensor
  return
}

// -----

// CHECK-LABEL:   func @f
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
  // Check propagation through multiple ops.
  // CHECK:           torch.aten.tanh %{{.*}} : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
  // CHECK:           torch.aten.tanh %{{.*}} : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
  // CHECK:           torch.aten.tanh %{{.*}} : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
  %1 = torch.aten.tanh %arg0 : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor
  %2 = torch.aten.tanh %1 : !torch.vtensor -> !torch.vtensor
  %3 = torch.aten.tanh %2 : !torch.vtensor -> !torch.vtensor
  return %3 : !torch.vtensor
}

// -----

// Check rewriting logic in case of mixes of users that do/don't allow type
// refinement.
// CHECK-LABEL:   func @f
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> (!torch.vtensor, !torch.vtensor) {
  // CHECK: %[[REFINED_TYPE:.*]] = torch.aten.tanh %{{.*}} : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
  %1 = torch.aten.tanh %arg0 : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor
  // CHECK: %[[ORIGINAL_TYPE:.*]] = torch.tensor_static_info_cast %[[REFINED_TYPE]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
  // CHECK: torch.aten.tanh %[[REFINED_TYPE]] : !torch.vtensor<[2,3,?],f32> -> !torch.vtensor<[2,3,?],f32>
  %3 = torch.aten.tanh %1 : !torch.vtensor -> !torch.vtensor
  // CHECK: return %[[ORIGINAL_TYPE]], %[[ORIGINAL_TYPE]] : !torch.vtensor, !torch.vtensor
  return %1, %1 : !torch.vtensor, !torch.vtensor
}

// -----

// CHECK-LABEL:   func @f
// CHECK: %[[ATEN:.*]] = torch.aten.tanh %{{.*}} : !torch.vtensor -> !torch.vtensor<[2,3,?],f32>
// CHECK: %[[CAST:.*]] = torch.tensor_static_info_cast %[[ATEN]] : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
// CHECK: return %[[CAST]] : !torch.vtensor
func @f(%arg0: !torch.vtensor<[2,3,?],f32>) -> !torch.vtensor {
  %cast = torch.tensor_static_info_cast %arg0 : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
  br ^bb1(%cast: !torch.vtensor)
^bb1(%arg1: !torch.vtensor):
  %1 = torch.aten.tanh %arg1 : !torch.vtensor -> !torch.vtensor
  return %1 : !torch.vtensor
}

// -----

// CHECK-LABEL:   func @f
// CHECK: func private @callee
// CHECK-NEXT: torch.aten.tanh %{{.*}} : !torch.vtensor -> !torch.vtensor<[2,3,?],f32>
func @f() {
  module {
    func private @callee(%arg0: !torch.vtensor) {
      %1 = torch.aten.tanh %arg0 : !torch.vtensor -> !torch.vtensor
      return
    }
    func @caller(%arg0: !torch.vtensor<[2,3,?],f32>) {
      %cast = torch.tensor_static_info_cast %arg0 : !torch.vtensor<[2,3,?],f32> to !torch.vtensor
      call @callee(%cast) : (!torch.vtensor) -> ()
      return
    }
  }
  return
}
