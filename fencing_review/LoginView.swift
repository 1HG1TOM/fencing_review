import SwiftUI

struct LoginView: View {
    @State private var userID: String = ""
    var onLogin: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ログイン")
                .font(.largeTitle)
            
            TextField("ユーザIDを入力", text: $userID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                let trimmed = userID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onLogin(trimmed)
            }) {
                Text("ログイン")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(userID.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(userID.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }
}
