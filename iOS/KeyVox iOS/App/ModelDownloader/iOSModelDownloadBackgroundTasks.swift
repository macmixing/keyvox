import BackgroundTasks
import Foundation

enum iOSModelDownloadBackgroundTasks {
    static let identifier = "com.cueit.keyvox.model-download"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: true)
                return
            }

            processingTask.expirationHandler = {
                processingTask.setTaskCompleted(success: false)
            }

            Task { @MainActor in
                await iOSAppServiceRegistry.shared.modelManager.handleBestEffortBackgroundRepair()
                processingTask.setTaskCompleted(success: true)
            }
        }
    }

    static func scheduleRepairIfNeeded() {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
#if DEBUG
            print("iOSModelDownloadBackgroundTasks: failed to schedule background task: \(error.localizedDescription)")
#endif
        }
    }
}
