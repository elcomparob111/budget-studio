import SwiftUI
import MessageUI
import ContactsUI

/// System Messages composer with a prefilled invite body (and optional recipient).
struct MessageComposeSheet: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinish()
        }
    }

    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }
}

/// Pick a contact, then hand back the best phone number for SMS.
struct ContactPickerSheet: UIViewControllerRepresentable {
    var onPick: (String?) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String?) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let phone = contact.phoneNumbers.first?.value.stringValue
            onPick(phone)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }
}

enum InviteMessage {
    static func body(link: String, fromName: String) -> String {
        let first = fromName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        if first.isEmpty {
            return "Join my shared budget in Budget Studio:\n\(link)"
        }
        return "Hey — \(first) invited you to share a budget in Budget Studio:\n\(link)"
    }
}
