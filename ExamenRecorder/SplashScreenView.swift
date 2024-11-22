import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var rotation = 0.0
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            VStack {
                Image("CompanyLogo") // Make sure to add your logo to Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .scaleEffect(size)
                    .rotationEffect(.degrees(rotation))
            }
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 1.2
                }
                
                withAnimation(.linear(duration: 1.0).repeatCount(2, autoreverses: false)) {
                    self.rotation = 360
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
