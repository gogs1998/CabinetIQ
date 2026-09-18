import SwiftUI
import AVFoundation
import Photos
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var reminderService: ReminderService
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \DocumentEntity.createdAt, ascending: false)])
    private var documents: FetchedResults<DocumentEntity>
    @State private var fmToggle = false
    @State private var permissionStatuses = PermissionStatuses()

    var body: some View {
        NavigationStack {
            Form {
                Section("Your cabinet") {
                    LabeledContent("Documents", value: "\(documents.count)")
                    LabeledContent("With due dates", value: "\(documents.filter { $0.dueDate != nil }.count)")
                    LabeledContent("Reminders", value: reminderService.isAuthorized ? "On" : "Off")
                }

                Section("Privacy") {
                    Text("CabinetIQ is a vault, not a cloud product. OCR, classification, search, and answers all run on this iPhone. There is no account and no analytics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("On-Device Foundation Models") {
                    Toggle("Private Cloud Compute (coming soon)", isOn: $fmToggle)
                        .disabled(true)
                        .onChange(of: fmToggle) { _, newValue in
                            FieldExtractor.shared.useOnDeviceFM = newValue
                            RAGEngine.shared.fmToggleEnabled = newValue
                        }
                    Text("All processing stays on-device today. This toggle prepares for a future PCC pathway.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Permissions") {
                    PermissionRow(icon: "camera.viewfinder", title: "Camera", status: permissionStatuses.camera)
                    PermissionRow(icon: "photo.on.rectangle", title: "Photos", status: permissionStatuses.photos)
                    PermissionRow(icon: "bell", title: "Notifications", status: permissionStatuses.notifications)
                    PermissionRow(icon: "folder", title: "Files", status: permissionStatuses.files)
                    Button("Enable reminders") {
                        reminderService.requestAuthorization()
                    }
                    Button("Manage in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .task {
                permissionStatuses = await PermissionStatuses.fetch()
                reminderService.refreshStatus()
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let status: PermissionState

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(status.label)
                .foregroundStyle(status.color)
                .font(.subheadline)
        }
    }
}

private struct PermissionStatuses {
    var camera: PermissionState = .notDetermined
    var photos: PermissionState = .notDetermined
    var notifications: PermissionState = .notDetermined
    var files: PermissionState = .notRequired

    static func fetch() async -> PermissionStatuses {
        var statuses = PermissionStatuses()
        statuses.camera = PermissionState(cameraStatus: AVCaptureDevice.authorizationStatus(for: .video))
        statuses.photos = PermissionState(photoStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite))
        statuses.notifications = await PermissionState.notificationStatus()
        statuses.files = .notRequired
        return statuses
    }
}

private enum PermissionState {
    case granted
    case denied
    case limited
    case notDetermined
    case notRequired

    init(cameraStatus: AVAuthorizationStatus) {
        switch cameraStatus {
        case .authorized:
            self = .granted
        case .restricted, .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .notDetermined
        }
    }

    init(photoStatus: PHAuthorizationStatus) {
        switch photoStatus {
        case .authorized:
            self = .granted
        case .limited:
            self = .limited
        case .denied, .restricted:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .notDetermined
        }
    }

    static func notificationStatus() async -> PermissionState {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    continuation.resume(returning: .granted)
                case .denied:
                    continuation.resume(returning: .denied)
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                @unknown default:
                    continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    var label: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .limited:
            return "Limited"
        case .notDetermined:
            return "Not Asked"
        case .notRequired:
            return "Not Required"
        }
    }

    var color: Color {
        switch self {
        case .granted:
            return Theme.ok
        case .denied:
            return Theme.overdue
        case .limited:
            return Theme.soon
        case .notDetermined, .notRequired:
            return .secondary
        }
    }
}
