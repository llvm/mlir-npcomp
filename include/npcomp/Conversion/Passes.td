//===-- Passes.td - Pass definition file -------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef NPCOMP_CONVERSION_PASSES
#define NPCOMP_CONVERSION_PASSES

include "mlir/Pass/PassBase.td"

//===----------------------------------------------------------------------===//
// Torch conversions
//===----------------------------------------------------------------------===//

def ConvertTorchToStd : Pass<"convert-torch-to-std", "FuncOp"> {
  let summary = "Convert recognized Torch ops to Std ops";
  let constructor = "mlir::NPCOMP::createConvertTorchToStdPass()";
}

def ConvertTorchToSCF: Pass<"convert-torch-to-scf", "FuncOp"> {
  let summary = "Convert recognized Torch ops to SCF ops";
  let constructor = "mlir::NPCOMP::createConvertTorchToSCFPass()";
}

def ConvertTorchToLinalg : Pass<"convert-torch-to-linalg", "FuncOp"> {
  let summary = "Convert recognized Torch ops to Linalg ops";
  let description = [{
    Convert ATen ops to linalg ops.

    This pass's main responsibility is to bridge the world between ops
    that safely terminate the program in case of operand shape mismatches
    (ATen) and ops where such mismatches are undefined behavior (linalg).

    To model the termination of the program for implementing error guards,
    we use the `std.assert` op.
    This is a design decision that is at variance from other passes in npcomp,
    such as `convert-tcf-to-std` and `convert-tcf-to-linalg` which use the
    `shape` dialect's witness system (`shape.cstr_*` family of ops feeding into
    `shape.assuming` regions). This is a change in design decisions
    from those passes (which will be subsumed by this one). The reasons for this
    change are heuristic, but boil down to:
    1. The modeling of `shape.assuming` is odd, as it uses a region, which is
       not a good fit for modeling error guards. Regions mark a "start" and an
       "end" (which is their nesting property). But
       modeling assertions in the program doesn't fit into that. For assertions,
       only the "start" matters (once tested, a predicate remains true "forever"
       -- it doesn't end at the "yield" of the region).
       Thus, having regions places arbitrary "end"s that just add IR structure
       that has no semantic value for modeling this problem! (and to make things
       worse the "end"s, which we don't need, are what require "yielding"
       values, which interrupts use-def chains). Consider the different
       structural properties of regions:
       a. IsolatedFromAbove region:
          - "start" interrupts use-def chains,
          - "end" interrupts use-def chains
          - structurally protects from intra-block upward and downward
            code motion
       b. Capturing region (like `shape.assuming`):
          - "start" does not interrupt use-def chains,
          - "end" interrupts use-def chains
          - structurally protects from intra-block upward and downward
            code motion
       c. What we "ideally" want:
          - "start" interrupts use-def chains (can be pruned though)
          - no "end" IR structure!
          - structurally protects from intra-block upward code motion
            (but not downward code motion!)
          - Observation: We probably can't get all of this, but overall this
            problem is much better suited for a "MemorySSA"-like
            abstraction, call it "EffectSSA" which is constructed on-demand
            based on MLIR's effect modeling system (rather than
            `shape.assuming`, which only covers the effects the IR creator
            encoded -- with witnesses/`shape.assuming` -- it is easy to forget
            to handle effects other than those encoded in the
            witness structure).
    2. The presence of `shape.assuming` regions tends to create highly nested
       IR structures, which don't interoperate well with any other IR
       structures, and creates very bulky IR (and IR creation code). In general
       if we are going to do anything with anything (e.g. canonicalize) we
       end up needing need to either:
       a. Flatten the `shape.assuming` IR (defeating the purpose of having
          it).
       b. Do some sort of shape.assuming "region merging".
       c. Have special patterns that handle a subset of special cases (looking
          through "yields" and such) and don't generalize.
    3. Witnesses tend to encourage non-scalable peephole transformations, which
       tend to make analyses/transformations non-robust to the presence of
       control flow and side effecting ops (easy to forget to handle side
       effects other than those modeled by the witness system).
    4. All this code operates on ranked tensors, for which using individual
       SSA values for sizes (rather than a "shape type") seems to
       work really well at this level of abstraction based on prior experience
       in IREE. (unranked code tends to benefit from having a discrete
       "shape type" to model shapes).

    We will see if we end up needing something like `shape.assuming`, but for
    now, it seems likely we can do something simpler and just bypass it. The
    design of having an EffectSSA that is constructed on-demand seems very
    compelling for modeling effects more broadly.
  }];
  let constructor = "mlir::NPCOMP::createConvertTorchToLinalgPass()";
}

//===----------------------------------------------------------------------===//
// Basicpy conversions
//===----------------------------------------------------------------------===//

def ConvertBasicpyToStd : Pass<"convert-basicpy-to-std", "FuncOp"> {
  let summary = "Convert representable Basicpy ops to std";
  let constructor = "mlir::NPCOMP::createConvertBasicpyToStdPass()";
}

//===----------------------------------------------------------------------===//
// Numpy conversions
//===----------------------------------------------------------------------===//

def ConvertNumpyToTCF : Pass<"convert-numpy-to-tcf", "FuncOp"> {
  let summary = "Convert the numpy dialect to supported TCF ops";
  let constructor = "mlir::NPCOMP::createConvertNumpyToTCFPass()";
}

//===----------------------------------------------------------------------===//
// TCFToTCP
//===----------------------------------------------------------------------===//

def ConvertTCFToLinalg : Pass<"convert-tcf-to-linalg", "FuncOp"> {
  let summary = "Convert TCF to Linalg";
  let description = [{
    The intention is for this pass to convert mainly to linalg named ops.

    Because linalg is at the "TCP" layer of abstraction, this pass has to
    concern itself with generating guards for error cases.
  }];
  let constructor = "mlir::NPCOMP::createConvertTCFToLinalgPass()";
}

//===----------------------------------------------------------------------===//
// TCFToStd
//===----------------------------------------------------------------------===//

def ConvertTCFToStd : Pass<"convert-tcf-to-std", "FuncOp"> {
  let summary = "Convert TCF to Std";
  let constructor = "mlir::NPCOMP::createConvertTCFToStdPass()";
}

//===----------------------------------------------------------------------===//
// TCFToTCP
//===----------------------------------------------------------------------===//

def ConvertTCFToTCP : Pass<"convert-tcf-to-tcp", "FuncOp"> {
  let summary = "Convert TCF to TCP";
  let constructor = "mlir::NPCOMP::createConvertTCFToTCPPass()";
}

#endif // NPCOMP_CONVERSION_PASSES
