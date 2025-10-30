import SwiftUI

struct UnitSelector: View {
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(action: { selection = opt }) {
                    Text(opt)
                }
            }
        } label: {
            Text(selection)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hexString: "6A7282"))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 32, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }
}

