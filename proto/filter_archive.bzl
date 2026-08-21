"""Picks the single .a file out of a target's (possibly multi-file) DefaultInfo."""

def _filter_archive_impl(ctx):
    archives = [f for f in ctx.attr.target[DefaultInfo].files.to_list() if f.extension == "a"]
    if len(archives) != 1:
        fail("Expected exactly one .a file in {}, got: {}".format(ctx.attr.target.label, archives))
    return [DefaultInfo(files = depset(archives))]

filter_archive = rule(
    implementation = _filter_archive_impl,
    attrs = {
        "target": attr.label(),
    },
)
