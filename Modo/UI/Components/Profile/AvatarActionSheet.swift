import SwiftUI
import PhotosUI

struct AvatarActionSheet: View {
    let onChooseDefault: () -> Void
    @Binding var photoPickerItem: PhotosPickerItem?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color(hexString: "E5E7EB")).frame(width: 36, height: 5).padding(.top, 8)
            Text("Change avatar").font(.system(size: 17, weight: .semibold))
            VStack(spacing: 12) {
                Button(action: { onChooseDefault(); onClose() }) {
                    HStack {
                        Image(systemName: "person.circle").foregroundColor(Color(hexString: "364153"))
                        Text("Choose default avatar")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color(hexString: "99A1AF"))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hexString: "F9FAFB")))
                }
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle").foregroundColor(Color(hexString: "364153"))
                        Text("Upload picture")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(Color(hexString: "99A1AF"))
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(hexString: "F9FAFB")))
                }
                Button(role: .cancel, action: { onClose() }) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 8)
        }
        .presentationDetents([.height(240), .medium])
    }
}

