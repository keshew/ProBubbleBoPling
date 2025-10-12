import SwiftUI

struct NoInternet: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
 
    var isPortrait: Bool {
        verticalSizeClass == .regular && horizontalSizeClass == .compact
    }
    
    var isLandscape: Bool {
        verticalSizeClass == .compact && horizontalSizeClass == .regular
    }
    
    
    var body: some View {
        VStack {
            if isPortrait {
                ZStack {
                    Image("BGforNotifications")
                        .resizable()
                        .ignoresSafeArea()
                        .aspectRatio(contentMode: .fill)
                    
                    VStack(spacing: 50) {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Text("NO INTERNET CONNECTION")
                                .font(.custom("BlackHanSans-Regular", size: 24))
                                .outlineText(color: Color(red: 136/255, green: 0/255, blue: 74/255), width: 0.7)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            
                            Text("Stay tuned with best offers from our casino")
                                .font(.custom("PassionOne-Regular", size: 18))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(red: 186/255, green: 186/255, blue: 185/255))
                                .hidden()
                        }
                        .padding(.horizontal, 40)
                        
                    
                    }
                    .padding(.vertical, 30)
                }
            } else {
                ZStack {
                    Image("BGforNotificationsLandscape")
                        .resizable()
                        .ignoresSafeArea()
                        .aspectRatio(contentMode: .fill)
                    
                    VStack(spacing: 30) {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Text("NO INTERNET CONNECTION")
                                .font(.custom("BlackHanSans-Regular", size: 24))
                                .outlineText(color: Color(red: 136/255, green: 0/255, blue: 74/255), width: 0.7)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            
                            Text("Stay tuned with best offers from our casino")
                                .font(.custom("PassionOne-Regular", size: 18))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color(red: 186/255, green: 186/255, blue: 185/255))
                                .hidden()
                        }
                        .padding(.horizontal, 40)
                        
                      
                    }
                }
            }
        }
    }
}

#Preview {
    NoInternet()
}
