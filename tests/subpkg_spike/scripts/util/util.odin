package subpkg_util

// ----------------------------------------------------------------------------
// util — a PURE HELPER subpackage: no `//gd:` markers, no annotations, so scriptgen
// emits nothing here (it did not before this change either — the difference is that
// its ANNOTATED sibling ui/ now gets a generated file, and util/ still does not).
// Imported by both the module root and ui/, which is a legal DAG edge; the one shape
// that is refused is a subpackage importing the module ROOT (an import cycle, since
// the root's generated manifest imports every script subpackage).
// ----------------------------------------------------------------------------

STEP :: 7
