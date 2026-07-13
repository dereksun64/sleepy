Execute docs/iterations/0001-skeleton/implementation-plan.md.

Before coding:
1. Read README.md.
2. Read docs/agents.md.
3. Read docs/product.md.
4. Read docs/architecture.md.
5. Read docs/iterations/0001-skeleton/spec.md.
6. Read docs/iterations/0001-skeleton/implementation-plan.md.
7. Check git status.

Execution rules:
- Follow the implementation plan task-by-task.
- Keep the implementation ponytail-simple.
- Build the smallest working native iOS skeleton.
- Do not expand scope beyond 0001-skeleton.
- Do not polish UI.
- Do not add custom routines, HealthKit, iCloud, widgets, Live Activities, accountability partners, weekly reports, shared challenges, or collectible systems.
- Do not add DeviceActivity extensions or App Groups unless the current task explicitly requires them.
- Prefer one simple store and plain SwiftUI screens over extra layers.
- Add services only when touching Apple frameworks or needing a small test seam.
- Do not introduce TCA, Clean Architecture, repositories, or broad view model hierarchies.

During execution:
- Complete one task at a time.
- Run the specified build/test command after each task when practical.
- If the exact simulator name is unavailable, list available simulators and use an available iPhone simulator.
- Commit after each completed task using the commit message from the plan or a similarly concise message.
- Update docs/iterations/0001-skeleton/checklist.md as tasks are completed.
- Update docs/iterations/0001-skeleton/test-notes.md with:
  - command run
  - result
  - simulator/device used
  - any skipped checks and why

Verification:
- At the end, run the full test command from the plan.
- Run the final build command from the plan.
- Confirm git status is clean.
- Push the branch to origin/develop.

If something fails:
- Diagnose the smallest root cause.
- Fix only what is needed for the 0001 skeleton.
- Record important failures or skipped real-device checks in test-notes.md.
- Do not silently remove tests or scope unless absolutely necessary; explain any change in the final summary.

Final response:
- Summarize what was built.
- List tests/builds run and their results.
- Mention any real-device items not tested.
- Include final commit hashes.