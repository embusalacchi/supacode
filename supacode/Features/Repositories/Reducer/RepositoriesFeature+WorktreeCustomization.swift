import ComposableArchitecture
import Foundation
import OrderedCollections
import SupacodeSettingsShared

extension RepositoriesFeature {
  /// Dedicated reducer for the per-worktree customization flow. Lives in its own file so the main
  /// `body` switch stays under the Swift type-checker's complexity limit.
  static var worktreeCustomizationReducer: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .requestCustomizeWorktree(let worktreeID, let repositoryID):
        guard let repository = state.repositories[id: repositoryID],
          let worktree = repository.worktrees.first(where: { $0.id == worktreeID })
        else {
          repositoriesLogger.warning(
            "requestCustomizeWorktree dropped: unknown wt=\(worktreeID) repo=\(repositoryID)"
          )
          return .none
        }
        // Git main worktree is repository-level (use requestCustomizeRepository instead). The
        // folder synthetic worktree IS the row, so we allow it through.
        if repository.isGitRepository, state.isMainWorktree(worktree) {
          repositoriesLogger.warning(
            "requestCustomizeWorktree dropped: git main worktree is repository-level wt=\(worktreeID)"
          )
          return .none
        }
        let bucket = state.sidebar.currentBucket(of: worktreeID, in: repositoryID)
        let storedItem = bucket.flatMap {
          state.sidebar.sections[repositoryID]?.buckets[$0]?.items[worktreeID]
        }
        // For folder synthetic worktrees, default name = repository name (what the row shows when
        // no override). For git worktrees, default name = branch name.
        let defaultName = repository.isGitRepository ? worktree.name : repository.name
        state.worktreeCustomization = WorktreeCustomizationFeature.State(
          worktreeID: worktreeID,
          repositoryID: repositoryID,
          defaultName: defaultName,
          title: storedItem?.title ?? "",
          color: storedItem?.color,
          group: storedItem?.group ?? ""
        )
        return .none

      case .worktreeCustomization(.presented(.delegate(.cancel))):
        state.worktreeCustomization = nil
        return .none

      case .worktreeCustomization(
        .presented(.delegate(.save(let worktreeID, let repositoryID, let title, let color, let group)))
      ):
        // Always overwrite (user save intent); falls back to `.unpinned` when the row hasn't been
        // seeded into a bucket yet (folder synthetic before first reconcile, deeplink/palette).
        state.$sidebar.withLock { sidebar in
          sidebar.setCustomization(title: title, color: color, worktree: worktreeID, in: repositoryID)
          sidebar.setGroup(group, worktree: worktreeID, in: repositoryID)
        }
        syncSidebar(&state)
        state.worktreeCustomization = nil
        return .none

      case .worktreeCustomization(.dismiss):
        state.worktreeCustomization = nil
        return .none

      case .setWorktreeAppearance(let worktreeID, let repositoryID, let title, let color):
        state.$sidebar.withLock { sidebar in
          sidebar.setCustomization(title: title, color: color, worktree: worktreeID, in: repositoryID)
        }
        syncSidebar(&state)
        return .none

      case .setWorktreeGroup(let worktreeID, let repositoryID, let group):
        // Same row eligibility as the sheet: git main worktrees are repository-level.
        guard let repository = state.repositories[id: repositoryID],
          let worktree = repository.worktrees.first(where: { $0.id == worktreeID }),
          !(repository.isGitRepository && state.isMainWorktree(worktree))
        else {
          repositoriesLogger.warning("setWorktreeGroup dropped: wt=\(worktreeID) repo=\(repositoryID)")
          return .none
        }
        let normalized = group.flatMap(SidebarGroupNesting.normalized)
        state.$sidebar.withLock { sidebar in
          sidebar.setGroup(normalized, worktree: worktreeID, in: repositoryID)
        }
        syncSidebar(&state)
        return .none

      case .sidebarGroupExpansionChanged(let path, let isExpanded):
        state.$sidebar.withLock { sidebar in
          if isExpanded {
            sidebar.collapsedGroups.remove(path)
          } else {
            sidebar.collapsedGroups.insert(path)
          }
        }
        return .none

      default:
        return .none
      }
    }
  }
}
