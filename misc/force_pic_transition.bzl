"""Transition to force `--force_pic` for a single `cc_binary`.

This is needed because, empirically, a plain `cc_binary(linkshared = True)`
here still fails to link with "dangerous relocation ... recompile with
-fPIC" against non-PIC objects (both our own generated proto code and
protobuf's own timestamp_cc_proto) - this toolchain
(@sonic_build_infra//toolchains/gcc) does not automatically select PIC
variants of a linkshared binary's transitive deps the way a standard Bazel
C++ toolchain does. Confirmed by attempting the plain cc_binary form first
and hitting this exact link failure before adding this transition.
"""

def _force_pic_transition_impl(_settings, _attr):
    return {"//command_line_option:force_pic": True}

force_pic_transition = transition(
    implementation = _force_pic_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:force_pic"],
)

def _transitioned_cc_binary_impl(ctx):
    binary = ctx.attr.binary[0]
    files = binary[DefaultInfo].files.to_list()
    if len(files) != 1:
        fail("Please make sure that target {} produces exactly one file".format(ctx.label))

    original_file = files[0]
    # Use this wrapper target's own name for the output file (not the inner
    # binary's basename): the inner binary is named "..._raw"/"..._raw.so"
    # to avoid colliding with this target's label, so its default
    # lib<name>.so-style output name wouldn't match what consumers of the
    # wrapper expect (e.g. "_utils.so"). Each force_pic_cc_binary instance in
    # a package has a distinct label name, so declaring the output directly
    # as that name (no extra directory nesting) can't collide.
    new_file = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.run_shell(
        inputs = [original_file],
        outputs = [new_file],
        command = "cp {} {}".format(original_file.path, new_file.path),
    )
    return [DefaultInfo(files = depset([new_file]))]

force_pic_cc_binary = rule(
    implementation = _transitioned_cc_binary_impl,
    attrs = {
        "binary": attr.label(cfg = force_pic_transition),
    },
)
