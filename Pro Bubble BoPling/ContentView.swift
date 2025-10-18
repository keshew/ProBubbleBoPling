import SwiftUI
import AVFoundation
import AVKit
import Photos
import UIKit

// Data Models

struct GameFrame: Codable {
    var bowlRolls: [Int] = []
}

struct Game: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var frames: [GameFrame] = Array(repeating: GameFrame(), count: 10)
    
    var rolls: [Int] {
        frames.flatMap { $0.bowlRolls }
    }
    
    var totalScore: Int {
        var score = 0
        var rollIndex = 0
        let rollCount = rolls.count
        
        for _ in 0..<10 {
            if rollIndex >= rollCount { break }
            
            if isStrike(rollIndex: rollIndex) {
                score += 10 + strikeBonus(rollIndex: rollIndex)
                rollIndex += 1
            } else if isSpare(rollIndex: rollIndex) {
                score += 10 + spareBonus(rollIndex: rollIndex)
                rollIndex += 2
            } else {
                score += rolls[rollIndex] + (rollIndex + 1 < rollCount ? rolls[rollIndex + 1] : 0)
                rollIndex += 2
            }
        }
        return score
    }
    
    private func isStrike(rollIndex: Int) -> Bool {
        rollIndex < rolls.count && rolls[rollIndex] == 10
    }
    
    private func isSpare(rollIndex: Int) -> Bool {
        rollIndex + 1 < rolls.count && rolls[rollIndex] + rolls[rollIndex + 1] == 10
    }
    
    private func strikeBonus(rollIndex: Int) -> Int {
        let next = rollIndex + 1 < rolls.count ? rolls[rollIndex + 1] : 0
        let nextNext = rollIndex + 2 < rolls.count ? rolls[rollIndex + 2] : 0
        return next + nextNext
    }
    
    private func spareBonus(rollIndex: Int) -> Int {
        rollIndex + 2 < rolls.count ? rolls[rollIndex + 2] : 0
    }
    
    var strikeCount: Int {
        var count = 0
        var rollIndex = 0
        for _ in 0..<10 {
            if rollIndex >= rolls.count { break }
            if isStrike(rollIndex: rollIndex) {
                count += 1
                rollIndex += 1
            } else {
                rollIndex += 2
            }
        }
        return count
    }
    
    var spareCount: Int {
        var count = 0
        var rollIndex = 0
        for _ in 0..<10 {
            if rollIndex >= rolls.count { break }
            if isStrike(rollIndex: rollIndex) {
                rollIndex += 1
            } else if isSpare(rollIndex: rollIndex) {
                count += 1
                rollIndex += 2
            } else {
                rollIndex += 2
            }
        }
        return count
    }
}

struct Goal: Codable, Identifiable {
    var id = UUID()
    var title: String
    var target: Double
    var current: Double = 0
    var isCompleted: Bool = false
}

struct VideoAnalysis: Codable, Identifiable {
    var id = UUID()
    var videoURL: URL?
    var notes: [String] = []
    var markers: [Double] = []
}

struct SavedProfile: Codable {
    var gamesPlayed: Int = 0
    var personalBest: Int = 0
    var achievements: [String] = []
}

struct UserProfile {
    var avatar: Image = Image(systemName: "person.circle.fill")
    var gamesPlayed: Int = 0
    var personalBest: Int = 0
    var achievements: [String] = []
}

class AppData: ObservableObject {
    @Published var games: [Game] = []
    @Published var goals: [Goal] = []
    @Published var videos: [VideoAnalysis] = []
    @Published var profile: UserProfile = UserProfile()
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        loadData()
    }
    
    private func loadData() {
        if let gamesData = UserDefaults.standard.data(forKey: "games") {
            if let loadedGames = try? decoder.decode([Game].self, from: gamesData) {
                games = loadedGames
            }
        }
        if let goalsData = UserDefaults.standard.data(forKey: "goals") {
            if let loadedGoals = try? decoder.decode([Goal].self, from: goalsData) {
                goals = loadedGoals
            }
        }
        if let videosData = UserDefaults.standard.data(forKey: "videos") {
            if let loadedVideos = try? decoder.decode([VideoAnalysis].self, from: videosData) {
                videos = loadedVideos
            }
        }
        if let profileData = UserDefaults.standard.data(forKey: "profile") {
            if let savedProfile = try? decoder.decode(SavedProfile.self, from: profileData) {
                profile = UserProfile(avatar: Image(systemName: "person.circle.fill"), gamesPlayed: savedProfile.gamesPlayed, personalBest: savedProfile.personalBest, achievements: savedProfile.achievements)
            }
        }
    }
    
    func saveData() {
        if let gamesData = try? encoder.encode(games) {
            UserDefaults.standard.set(gamesData, forKey: "games")
        }
        if let goalsData = try? encoder.encode(goals) {
            UserDefaults.standard.set(goalsData, forKey: "goals")
        }
        if let videosData = try? encoder.encode(videos) {
            UserDefaults.standard.set(videosData, forKey: "videos")
        }
        let savedProfile = SavedProfile(gamesPlayed: profile.gamesPlayed, personalBest: profile.personalBest, achievements: profile.achievements)
        if let profileData = try? encoder.encode(savedProfile) {
            UserDefaults.standard.set(profileData, forKey: "profile")
        }
    }
    
    var averageScoreToday: Int {
        let todayGames = games.filter { Calendar.current.isDateInToday($0.date) }
        guard !todayGames.isEmpty else { return 0 }
        let sum = todayGames.reduce(0) { $0 + $1.totalScore }
        return sum / todayGames.count
    }
    
    var averageScoreWeek: Int {
        let weekGames = games.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        guard !weekGames.isEmpty else { return 0 }
        let sum = weekGames.reduce(0) { $0 + $1.totalScore }
        return sum / weekGames.count
    }
    
    var averageScoreMonth: Int {
        let monthGames = games.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        guard !monthGames.isEmpty else { return 0 }
        let sum = monthGames.reduce(0) { $0 + $1.totalScore }
        return sum / monthGames.count
    }
    
    var averageScoreSeason: Int {
        let seasonGames = games.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .quarter) }
        guard !seasonGames.isEmpty else { return 0 }
        let sum = seasonGames.reduce(0) { $0 + $1.totalScore }
        return sum / seasonGames.count
    }
    
    var strikePercentage: Double {
        let totalFrames = games.count * 10
        guard totalFrames > 0 else { return 0 }
        let totalStrikes = games.reduce(0) { $0 + $1.strikeCount }
        return Double(totalStrikes) / Double(totalFrames) * 100
    }
    
    var sparePercentage: Double {
        let totalFrames = games.count * 10
        guard totalFrames > 0 else { return 0 }
        let totalSpares = games.reduce(0) { $0 + $1.spareCount }
        return Double(totalSpares) / Double(totalFrames) * 100
    }
    
    func addGame(_ game: Game) {
        games.append(game)
        profile.gamesPlayed += 1
        if game.totalScore > profile.personalBest {
            profile.personalBest = game.totalScore
        }
        if game.totalScore == 300 {
            if !profile.achievements.contains("Perfect Game") {
                profile.achievements.append("Perfect Game")
            }
        }
        let overallAverage = games.reduce(0) { $0 + $1.totalScore } / max(1, games.count)
        if overallAverage >= 200 {
            if !profile.achievements.contains("Average 200+") {
                profile.achievements.append("Average 200+")
            }
        }
        updateGoals()
        saveData()
    }
    
    func updateGoals() {
        for i in 0..<goals.count {
            var goal = goals[i]
            if goal.title.contains("Strike%") {
                goal.current = strikePercentage
            } else if goal.title.contains("Spare%") {
                goal.current = sparePercentage
            }
            goal.isCompleted = goal.current >= goal.target
            goals[i] = goal
        }
        saveData()
    }
}

// Custom Views

struct BubbleButton: View {
    var text: String? = nil
    var icon: String? = nil
    var action: () -> Void
    var glow: Bool = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(RadialGradient(gradient: Gradient(colors: [Color.purple.opacity(0.9), Color.pink]), center: .center, startRadius: 0, endRadius: 60))
                    .shadow(color: .pink.opacity(0.6), radius: glow ? 12 : 4)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .blur(radius: 4)
                    .offset(x: -8, y: -8)
                    .blendMode(.overlay)
                
                if let text = text {
                    Text(text)
                        .foregroundColor(.white)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 70, height: 70)
            .scaleEffect(isPressed ? 1.15 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
    }
}

struct FrameBubble: View {
    var frame: GameFrame
    var onTap: () -> Void
    @State private var animateGlow = false
    
    var body: some View {
        let sym = symbol(for: frame)
        let col = (sym == "✨" || sym == "/") ? Color.purple : Color.gray.opacity(0.7)
        let glow = sym == "✨"
        
        Button(action: onTap) {
            Circle()
                .fill(col)
                .overlay(
                    Text(sym)
                        .foregroundColor(.white)
                        .font(.system(.body, design: .rounded, weight: .bold))
                )
                .frame(width: 50, height: 50)
                .shadow(color: glow ? .pink : .clear, radius: animateGlow ? 10 : 4)
        }
        .onChange(of: sym) { newSym in
            if newSym == "✨" {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(3)) {
                    animateGlow.toggle()
                }
            }
        }
    }
    
    func symbol(for frame: GameFrame) -> String {
        let r = frame.bowlRolls
        if r.isEmpty { return "?" }
        if r.first == 10 {
            return "✨"
        } else if r.count >= 2 && r[0] + r[1] == 10 {
            return "/"
        } else if r.reduce(0, +) == 0 {
            return "-"
        } else {
            return r.map { "\($0)" }.joined(separator: "/")
        }
    }
}

struct GoalBubble: View {
    var goal: Goal
    @State private var progress: CGFloat = 0
    @State private var isBouncing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.black.opacity(0.2)]), center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 130, height: 130)
                .shadow(color: .pink.opacity(0.4), radius: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 10)
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-90))
                .shadow(color: .pink.opacity(0.5), radius: 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        progress = CGFloat(min(1.0, goal.current / goal.target))
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                        isBouncing = true
                    }
                }
            
            VStack(spacing: 6) {
                Text(goal.title)
                    .foregroundColor(.white)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Text("\(Int(goal.current))% / \(Int(goal.target))%")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
        }
        .scaleEffect(isBouncing ? 1.05 : 0.95)
    }
}

struct GameBubble: View {
    var game: Game
    var onTap: () -> Void
    @State private var animateGlow = false
    
    var body: some View {
        let score = game.totalScore
        let col = score >= 200 ? Color.purple : Color.gray.opacity(0.7)
        let glow = score >= 200
        
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(col)
                    .frame(width: 70, height: 70)
                    .shadow(color: glow ? .pink : .clear, radius: animateGlow ? 12 : 4)
                
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .blur(radius: 4)
                    .offset(x: -8, y: -8)
                    .blendMode(.overlay)
                
                Text("\(score)")
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
        }
        .onAppear {
            if glow {
                withAnimation(.easeInOut(duration: 0.5).repeatCount(3)) {
                    animateGlow.toggle()
                }
            }
        }
    }
}

struct PyramidChart: View {
    var games: [Game]
    
    var body: some View {
        let numGames = games.count
        let levels = Int(ceil(sqrt(Double(numGames))))
        VStack(spacing: 8) {
            ForEach(0..<levels, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<(row + 1), id: \.self) { col in
                        if (row * (row + 1) / 2 + col) < numGames {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 35, height: 35)
                                .shadow(color: .pink.opacity(0.5), radius: 3)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct FrameInputView: View {
    @Binding var frame: GameFrame
    var isLast: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var roll1: Int = 0
    @State private var roll2: Int = 0
    @State private var roll3: Int = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Frame Input").font(.system(.headline, design: .rounded))) {
                    Picker("First Roll", selection: $roll1) {
                        ForEach(0..<11) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    
                    if roll1 < 10 {
                        Picker("Second Roll", selection: $roll2) {
                            ForEach(0..<(11 - roll1)) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                    }
                    
                    if isLast && (roll1 == 10 || roll1 + roll2 == 10) {
                        Picker("Third Roll", selection: $roll3) {
                            ForEach(0..<11) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Enter Frame")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var newRolls: [Int] = [roll1]
                        if roll1 < 10 {
                            newRolls.append(roll2)
                        }
                        if isLast && (roll1 == 10 || roll1 + roll2 == 10) {
                            newRolls.append(roll3)
                        }
                        frame.bowlRolls = newRolls
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .onAppear {
                if !frame.bowlRolls.isEmpty {
                    roll1 = frame.bowlRolls[0]
                }
                if frame.bowlRolls.count > 1 {
                    roll2 = frame.bowlRolls[1]
                }
                if frame.bowlRolls.count > 2 {
                    roll3 = frame.bowlRolls[2]
                }
            }
        }
    }
}

struct GameEditView: View {
    @Binding var game: Game
    @Environment(\.dismiss) var dismiss
    @State private var selectedFrameIndex: FrameIndex? = nil
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Edit Game")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<10, id: \.self) { i in
                            FrameBubble(frame: game.frames[i]) {
                                selectedFrameIndex = FrameIndex(id: i, selectedFrameIndex: i)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Text("Total Score: \(game.totalScore)")
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                
                Button("Save Game") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.5), radius: 6)
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
        .sheet(item: $selectedFrameIndex) { index in
            FrameInputView(frame: $game.frames[index.selectedFrameIndex ?? 0], isLast: index.selectedFrameIndex == 9)
        }
    }
}

// Main App

extension LoadingView {
    func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                if canAskAgain() {
                    isNotif = true
                } else {
                    sendConfigRequest()
                }
            case .denied:
                sendConfigRequest()
            case .authorized, .provisional, .ephemeral:
                sendConfigRequest()
            @unknown default:
                sendConfigRequest()
            }
        }
    }
    
    func canAskAgain() -> Bool {
        if let lastDenied = UserDefaults.standard.object(forKey: lastDeniedKey) as? Date {
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            return lastDenied < threeDaysAgo
        }
        return true
    }
    
    func sendConfigRequest() {
        let configNoMoreRequestsKey = "config_no_more_requests"
        if UserDefaults.standard.bool(forKey: configNoMoreRequestsKey) {
            print("Config requests are disabled by flag, exiting sendConfigRequest")
            DispatchQueue.main.async {
                finishLoadingWithoutWebview()
            }
            return
        }

        guard let conversionDataJson = UserDefaults.standard.data(forKey: "conversion_data") else {
            print("Conversion data not found in UserDefaults")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishLoadingWithoutWebview()
            }
            return
        }

        guard var conversionData = (try? JSONSerialization.jsonObject(with: conversionDataJson, options: [])) as? [String: Any] else {
            print("Failed to deserialize conversion data")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishLoadingWithoutWebview()
            }
            return
        }

        conversionData["push_token"] = UserDefaults.standard.string(forKey: "fcmToken") ?? ""
        conversionData["af_id"] = UserDefaults.standard.string(forKey: "apps_flyer_id") ?? ""
        conversionData["bundle_id"] = "com.bubblebopling.ProBubbleBoPling"
        conversionData["os"] = "iOS"
        conversionData["store_id"] = "6753350433"
        conversionData["locale"] = Locale.current.identifier
        conversionData["firebase_project_id"] = "623398059823"

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: conversionData, options: [])
                    let url = URL(string: "https://probubblebopling.com/config.php")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Request error: \(error)")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishLoadingWithoutWebview()
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishLoadingWithoutWebview()
                    }
                    return
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Server returned status code \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                        finishLoadingWithoutWebview()
                    }
                    return
                }

                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            print("Config response JSON: \(json)")
                            DispatchQueue.main.async {
                                handleConfigResponse(json)
                            }
                        }
                    } catch {
                        print("Failed to parse response JSON: \(error)")
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                            finishLoadingWithoutWebview()
                        }
                    }
                }
            }

            task.resume()
        } catch {
            print("Failed to serialize request body: \(error)")
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
                finishLoadingWithoutWebview()
            }
        }
    }

    func handleConfigResponse(_ jsonResponse: [String: Any]) {
        if let ok = jsonResponse["ok"] as? Bool, ok,
           let url = jsonResponse["url"] as? String,
           let expires = jsonResponse["expires"] as? TimeInterval {
            UserDefaults.standard.set(url, forKey: configUrlKey)
            UserDefaults.standard.set(expires, forKey: configExpiresKey)
            UserDefaults.standard.removeObject(forKey: configNoMoreRequestsKey)
            UserDefaults.standard.synchronize()
            
            guard urlFromNotification == nil else {
                return
            }
            self.url = URLModel(urlString: url)
            print("Config saved: url = \(url), expires = \(expires)")
            
        } else {
            UserDefaults.standard.set(true, forKey: configNoMoreRequestsKey)
            UserDefaults.standard.synchronize()
            print("No valid config or error received, further requests disabled")
            finishLoadingWithoutWebview()
        }
    }
    
    func finishLoadingWithoutWebview() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isMain = true
        }
    }
}

// Screens

struct HomeView: View {
    @EnvironmentObject var appData: AppData
    @State var addGameFullConver = false
    @State var statsFullConver = false
    @State var goalsFullConver = false
    @State var videoAnalysisFullConver = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Pro Bubble BoPling")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                VStack {
                    BubbleButton(text: "\(appData.averageScoreToday)") {}
                        .scaleEffect(1.5)
                    Text("Today's Average Score")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(.subheadline, design: .rounded))
                }
                
                HStack(spacing: 20) {
                    VStack {
                        BubbleButton(icon: "plus") {
                            addGameFullConver = true
                        }
                        Text("Add Game")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(.caption, design: .rounded))
                    }
                    
                    VStack {
                        BubbleButton(icon: "chart.bar") {
                            statsFullConver = true
                        }
                        Text("Stats")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(.caption, design: .rounded))
                    }
                    
                    VStack {
                        BubbleButton(icon: "target") {
                            goalsFullConver = true
                        }
                        Text("Goals")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(.caption, design: .rounded))
                    }
                    
                    VStack {
                        BubbleButton(icon: "video") {
                            videoAnalysisFullConver = true
                        }
                        Text("Video")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(.caption, design: .rounded))
                    }
                }
                
                NavigationLink {
                    ProfileView().environmentObject(appData)
                } label: {
                    Text("Profile")
                        .foregroundColor(.pink)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(12)
                }
            }
            .padding(.vertical, 40)
            .fullScreenCover(isPresented: $addGameFullConver) {
                AddGameView().environmentObject(appData)
            }
            .fullScreenCover(isPresented: $statsFullConver) {
                StatsView().environmentObject(appData)
            }
            .fullScreenCover(isPresented: $goalsFullConver) {
                GoalsView().environmentObject(appData)
            }
            .fullScreenCover(isPresented: $videoAnalysisFullConver) {
                VideoAnalysisView().environmentObject(appData)
            }
        }
    }
}

struct FrameIndex: Identifiable {
    var id: Int
    var selectedFrameIndex: Int? = nil
}

struct GameIndex: Identifiable {
    var id: UUID
    var selectedGameIndex: Int
}

struct AddGameView: View {
    @EnvironmentObject var appData: AppData
    @State private var games: [Game] = []
    @State private var selectedGameIndex: GameIndex? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Games")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(games.indices, id: \.self) { index in
                            GameBubble(game: games[index]) {
                                selectedGameIndex = GameIndex(id: games[index].id, selectedGameIndex: index)
                            }
                        }
                        BubbleButton(icon: "plus") {
                            games.append(Game())
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button("Save All Games") {
                    games.forEach { appData.addGame($0) }
                    games.removeAll()
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.5), radius: 6)
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
        .sheet(item: $selectedGameIndex) { index in
            GameEditView(game: $games[index.selectedGameIndex])
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Statistics")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Average Week", value: "\(appData.averageScoreWeek)")
                        StatRow(label: "Average Month", value: "\(appData.averageScoreMonth)")
                        StatRow(label: "Average Season", value: "\(appData.averageScoreSeason)")
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        StatRow(label: "Strike %", value: String(format: "%.1f%%", appData.strikePercentage))
                        StatRow(label: "Spare %", value: String(format: "%.1f%%", appData.sparePercentage))
                    }
                    .padding(.horizontal)
                    
                    PyramidChart(games: appData.games)
                }
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.9))
                .font(.system(.body, design: .rounded, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(.pink)
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct GoalsView: View {
    @EnvironmentObject var appData: AppData
    @State private var newGoalTitle = ""
    @State private var newGoalTarget = 0.0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Goals")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                        ForEach(appData.goals) { goal in
                            GoalBubble(goal: goal)
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    TextField("Goal Title (e.g., Strike% 50)", text: $newGoalTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.3))
                                .shadow(color: .pink.opacity(0.3), radius: 4)
                        )
                        .padding(.horizontal)
                    
                    TextField("Target (%)", value: $newGoalTarget, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .keyboardType(.decimalPad)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.3))
                                .shadow(color: .pink.opacity(0.3), radius: 4)
                        )
                        .padding(.horizontal)
                    
                    Button("Add Goal") {
                        let newGoal = Goal(title: newGoalTitle, target: newGoalTarget)
                        appData.goals.append(newGoal)
                        newGoalTitle = ""
                        newGoalTarget = 0.0
                        appData.updateGoals()
                    }
                    .foregroundColor(.white)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16)
                    .shadow(color: .pink.opacity(0.5), radius: 6)
                    .padding(.horizontal)
                }
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
    }
}

struct VideoAnalysisView: View {
    @EnvironmentObject var appData: AppData
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var selectedVideo: VideoAnalysis? = nil
    @State private var showCameraError = false
    @State private var showPermissionError = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Video Analysis")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                Button("Record Video") {
                    checkCameraPermission { granted in
                        if granted {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) && (UIImagePickerController.availableMediaTypes(for: .camera)?.contains("public.movie") ?? false) {
                                showCamera = true
                            } else {
                                showCameraError = true
                            }
                        } else {
                            showPermissionError = true
                        }
                    }
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.5), radius: 6)
                .padding(.horizontal)
                
                Button("Pick Video") {
                    showLibrary = true
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.5), radius: 6)
                .padding(.horizontal)
                
                List {
                    ForEach(appData.videos) { video in
                        Button(action: { selectedVideo = video }) {
                            HStack {
                                Text("Video \(video.id.uuidString.prefix(8))")
                                    .foregroundColor(.white)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.pink)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical, 40)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedVideo: addVideoURL)
        }
        .sheet(isPresented: $showLibrary) {
            ImagePicker(sourceType: .photoLibrary, selectedVideo: addVideoURL)
        }
        .sheet(item: $selectedVideo) { video in
            VideoDetailView(video: Binding(
                get: { video },
                set: { updated in
                    if let index = appData.videos.firstIndex(where: { $0.id == updated.id }) {
                        appData.videos[index] = updated
                        appData.saveData()
                    }
                }
            ))
        }
        .alert("Camera Not Available", isPresented: $showCameraError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Video recording is not supported on this device.")
        }
        .alert("Camera Permission Denied", isPresented: $showPermissionError) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to record videos.")
        }
    }
    
    func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    func addVideoURL(_ url: URL?) {
        guard let tempURL = url else { return }
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newURL = documentsDirectory.appendingPathComponent("video_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: tempURL, to: newURL)
            let newVideo = VideoAnalysis(videoURL: newURL)
            appData.videos.append(newVideo)
            appData.saveData()
        } catch {
            print("Error copying video: \(error)")
        }
    }
}

struct VideoDetailView: View {
    @Binding var video: VideoAnalysis
    @State private var newNote = ""
    let player: AVPlayer?
    @Environment(\.dismiss) var dismiss
    
    init(video: Binding<VideoAnalysis>) {
        self._video = video
        if let url = video.videoURL.wrappedValue {
            self.player = AVPlayer(url: url)
        } else {
            self.player = nil
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
                    .cornerRadius(12)
                
                Button("Add Marker") {
                    video.markers.append(player.currentTime().seconds)
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.5), radius: 6)
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    TextField("Add Note", text: $newNote)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple.opacity(0.3))
                                .shadow(color: .pink.opacity(0.3), radius: 4)
                        )
                    
                    Button("Save") {
                        if !newNote.isEmpty {
                            video.notes.append(newNote)
                            newNote = ""
                        }
                    }
                    .foregroundColor(.white)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .padding(.horizontal)
                    .background(LinearGradient(gradient: Gradient(colors: [.pink, .purple]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                }
                .padding(.horizontal)
                
                List {
                    Section(header: Text("Markers").font(.system(.headline, design: .rounded))) {
                        ForEach(video.markers, id: \.self) { marker in
                            Text("Marker at \(String(format: "%.1f", marker)) seconds")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Section(header: Text("Notes").font(.system(.headline, design: .rounded))) {
                        ForEach(video.notes, id: \.self) { note in
                            Text(note)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.black.opacity(0.2))
                .cornerRadius(12)
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                Text("No Video Available")
                    .foregroundColor(.white)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded, weight: .bold))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 40)
        .background(LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom))
    }
}

struct ProfileView: View {
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.black, .purple.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Profile")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 4)
                
                appData.profile.avatar
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.pink, lineWidth: 3))
                    .shadow(color: .pink.opacity(0.5), radius: 6)
                
                VStack(spacing: 12) {
                    StatRow(label: "Games Played", value: "\(appData.profile.gamesPlayed)")
                    StatRow(label: "Personal Best", value: "\(appData.profile.personalBest)")
                }
                .padding(.horizontal)
                
                if !appData.profile.achievements.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                        
                        ForEach(appData.profile.achievements, id: \.self) { ach in
                            Text(ach)
                                .foregroundColor(.pink)
                                .font(.system(.body, design: .rounded))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 40)
        }
    }
}

// Custom ImagePicker for Video

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var selectedVideo: (URL?) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.selectedVideo(url)
            } else {
                parent.selectedVideo(nil)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.selectedVideo(nil)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(AppData())
    }
}
