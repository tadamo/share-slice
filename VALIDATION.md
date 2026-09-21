# MVP validation plan

Baseline: `3aec281`.

1. Build with the installed Xcode and fix compiler errors and warnings without adding features.
2. Run the geometry tests. Add regression coverage only for defects found during validation.
3. Launch the app and check Screen Recording consent, region drawing, moving, resizing, cancellation, and saved selection.
4. Check live cropping, preview exclusion, repeated start/stop, and preview close on the available displays. Record hardware limits separately from passes.
5. Guide a Teams window-sharing check with a remote viewer. Do not claim a pass without a viewer's result.
6. Record actual build, test, and runtime results in README.md, including remaining checks.
