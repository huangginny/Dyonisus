//
//  RatingCard.swift
//  Dionysus
//
//  Created by Ginny Huang on 1/15/20.
//  Copyright © 2020 Ginny Huang. All rights reserved.
//

import SwiftUI

struct ScoreBar: View {
    let percentage : Double
    let color : Color
    
    let strokeTemplate = RoundedRectangle(cornerRadius: 10, style: .continuous)
    
    func getStrokeForPercentage(cuePoint: Double) -> some View {
        if cuePoint > self.percentage {
            return AnyView(strokeTemplate.fill(COLOR_LIGHT_GRAY))
        } else if cuePoint + 20 <= percentage {
            return AnyView(strokeTemplate.fill(color))
        } else {
            let location = (self.percentage - cuePoint) / 20
            return AnyView(strokeTemplate.fill(
                LinearGradient(
                    gradient: .init(stops: [
                        Gradient.Stop(color: color, location: CGFloat(location)),
                        Gradient.Stop(color: COLOR_LIGHT_GRAY, location: CGFloat(location))
                    ]),
                    startPoint: .init(x: 0, y: 1),
                    endPoint: .init(x: 1, y: 1)
                )
            ))
        }
    }
    
    var body: some View {
        HStack(spacing:1) {
            ForEach([0,20,40,60,80], id: \.self) { cuePoint in
                self.getStrokeForPercentage(cuePoint: cuePoint).frame(height:15)
            }
        }
    }
}

struct YelpScoreBar: View {
    let score : Double
    
    func getImageAssetName() -> String {
        switch score {
        case 5.0...:
            return "regular_5"
        case 4.5 ..< 5.0:
            return "regular_4_half"
        case 4.0 ..< 4.5:
            return "regular_4"
        case 3.5 ..< 4.0:
            return "regular_3_half"
        case 3.0 ..< 3.5:
            return "regular_3"
        case 2.5 ..< 3.0:
            return "regular_2_half"
        case 2.0 ..< 2.5:
            return "regular_2"
        case 1.5 ..< 2.0:
            return "regular_1_half"
        default:
            return "regular_1"
        }
    }
    
    var body: some View {
        Image(getImageAssetName()).resizable().aspectRatio(contentMode: .fit)
    }
}

struct RatingCard: View {
    let horizontalPadding = CGFloat(10)
    let loader : InfoLoader
    @State var visiblePercentage = 0.0
    
    func getColor() -> Color {
        let actualPercentage = self.loader.place!.score! / Double(self.loader.plugin.totalScore) * 100
        if loader.place == nil {
            return COLOR_LIGHT_GRAY
        }
        switch actualPercentage {
        case 0..<40:
            return Color.red
        case 40..<60:
            return Color.orange
        case 60..<80:
            return Color.yellow
        case 80..<100:
            fallthrough
        default:
            return Color.init(red: 0, green: 0.6, blue: 0)
        }
    }
    
    var body: some View {
        HStack {
            if loader.isLoading {
                // Loading
                ActivityIndicator().padding(.leading, horizontalPadding)
                Text("Loading rating from \(loader.plugin.name)...")
                Spacer()
                Image(loader.plugin.logo).resizable()
                    .frame(width: 25, height: 25, alignment: .bottomTrailing)
                    .padding(.trailing, horizontalPadding)
            } else if loader.message != "" {
                // Place does not exist
                Text(loader.message).padding(.leading, horizontalPadding)
                Spacer()
                Image(loader.plugin.logo).resizable()
                    .frame(width: 25, height: 25, alignment: .bottomTrailing)
                    .padding(.trailing, horizontalPadding)
            } else {
                // Exising rating with score
                HStack(alignment: .bottom, spacing:0) {
                    Text("\(String(format: "%.1f", loader.place!.score!))")
                        .font(
                            .init(Font.system(
                                size: 40, weight: .regular, design: .default
                        )))
                        .lineLimit(1)
                    Text("/\(String(loader.plugin.totalScore))")
                        .font(
                            .init(Font.system(
                                size: 18, weight: .light, design: .default
                        )))
                        .lineLimit(1)
                }
                .foregroundColor(getColor())
                .frame(width:100)
                .padding(.leading, horizontalPadding)
                VStack {
                    Spacer()
                    HStack {
                        if loader.plugin.name == "Yelp" {
                            YelpScoreBar(score: loader.place!.score!)
                        } else if visiblePercentage > 0 {
                            ScoreBar(percentage: visiblePercentage, color: getColorFromHex(loader.plugin.colorCode))
                        }
                        HStack(spacing:0) {
                            Spacer()
                            Text(String(repeating: "$", count: loader.place!.price))
                            .padding(0)
                        }
                        .frame(width: 60)
                    }.onAppear {
                        let actualPercentage = self.loader.place!.score! / Double(self.loader.plugin.totalScore) * 100
                        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                            self.visiblePercentage = min(self.visiblePercentage + 1, actualPercentage)
                            if (self.visiblePercentage >= actualPercentage) {
                                timer.invalidate()
                            }
                        }
                    }
                    Spacer()
                    Divider()
                    HStack {
                        Spacer()
                        Text("by \(loader.place!.numOfScores!) user\(loader.place!.numOfScores! > 1 ? "s" : "") on ")
                            .font(.footnote)
                            .foregroundColor(.gray)
                        Image(loader.plugin.logo).resizable().frame(width: 25, height: 25, alignment: .bottomTrailing)
                    }
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, horizontalPadding)
            }
        }
        .padding()
        .onTapGesture {
            if let urlString = self.loader.place?.url {
                guard let url = URL(string: urlString) else { return }
                UIApplication.shared.open(url)
            }
        }
        .frame(height:150)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: COLOR_LIGHT_GRAY, radius: 10)
                .padding()
        )
    }
}

struct RatingCard_Previews: PreviewProvider {
    
    static var previews: some View {
        unrated.isLoading = false
        unrated.message = "I am unrated"
        return VStack {
            RatingCard(loader: InfoLoader(plugin: mockSetting.defaultSitePlugin, place: nil))
            RatingCard(loader: InfoLoader(
                plugin: mockSetting.defaultSitePlugin,
                place: ootp)
            )
            RatingCard(loader: unrated)
        }
        //.previewLayout(.fixed(width:375, height:100))
    }
}