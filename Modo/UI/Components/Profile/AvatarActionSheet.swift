import SwiftUI
import PhotosUI

struct AvatarActionSheet: View {
    let onChooseDefault: () -> Void
    @Binding var photoPickerItem: PhotosPickerItem?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(.separator))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            Text("Change avatar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                Button(action: { onChooseDefault(); onClose() }) {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.primary)
                        Text("Choose default avatar")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.primary)
                        Text("Upload picture")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                
                Button(role: .cancel, action: { onClose() }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.primary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 8)
        }
        .presentationDetents([.height(240), .medium])
    }
}

