//
//  utils.swift
//  Dionysus
//
//  Created by Ginny Huang on 1/11/20.
//  Copyright © 2020 Ginny Huang. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

func logMessage(_ message: String, fileName: String = #file, functionName: String = #function) {
    print("[DYONYSUS] | \(getCurrentTimestamp()) - \(fileName.components(separatedBy: "/").last ?? "") - \(functionName) \(message)")
}

func getCurrentTimestamp() -> String {
    let format = DateFormatter()
    format.timeZone = .current
    format.dateFormat = "HH:mm:ss.SSS Z"
    return format.string(from: Date())
}

func isNonEmptyString(_ str: String?) -> Bool {
    if let s = str, s.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
        return true
    }
    return false
}

func getRawPhoneNumber(_ str: String?) -> String? {
    return str?.compactMap({ $0.wholeNumberValue?.description}).joined()
}

func getFormattedDistance(_ meters: Double?) -> String? {
    if let meters = meters {
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.numberFormatter.maximumFractionDigits = 1
        let distanceStr = measurementFormatter.string(from: measurement)
        return "~\(distanceStr)"
    }
    return nil
}

func getScreenWidth() -> Int {
    return Int(ceil(UIScreen.main.bounds.width))
}

// Reference: https://www.iosapptemplates.com/blog/swift-programming/convert-hex-colors-to-uicolor-swift-4
func getColorFromHex(_ colorCode: String) -> Color {
    var hexString: String = colorCode.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if (hexString.hasPrefix("#")) {
        hexString = String(hexString.dropFirst())
    }
    let scanner = Scanner(string: hexString)
    var color: UInt64 = 0
    scanner.scanHexInt64(&color)
    let mask = 0x000000FF
    let r = Int(color >> 16) & mask
    let g = Int(color >> 8) & mask
    let b = Int(color) & mask
    let red   = Double(r) / 255.0
    let green = Double(g) / 255.0
    let blue  = Double(b) / 255.0
    return Color(red: red, green: green, blue: blue)
}

/**
  Algorithm:
    1. Return the candidate with a matching phone number
    2. Disregard all places with an unmatching postal code
    3. If none of the candidates have a matching phone number, return the best candidate using fuzzy matching
 */
func getBestMatchByFuzzyDistance(with place: PlaceInfoModel, candidates: [PlaceInfoModel]) -> PlaceInfoModel? {
    logMessage("Matching places with place: \(place)")
    if candidates.count == 0 { return nil}
    
    // Phone matching
    let originalPhone = getRawPhoneNumber(place.phone)
    if let originalPhone = originalPhone,
        let bestCandidate = candidates.first(where: {
            $0.phone?.suffix(7) == originalPhone.suffix(7) // phone matching, disregard area code
        })
    {
        return bestCandidate
    }
    return candidates
        .filter({$0.postalCode == nil
            || place.postalCode == nil
            || $0.postalCode == place.postalCode}) // disregard bad post code
        .sorted(by: { // get best fuzzy match result
            getMatchingScore(to: place, current: $0) < getMatchingScore(to: place, current: $1)
        })
        .first
}

func getMatchingScore(to origin: PlaceInfoModel, current: PlaceInfoModel) -> Double {
    let nameMatching = FUSE.search(current.name, in: origin.name)
    let addrMatching = FUSE.search(current.formattedAddress[0], in: origin.formattedAddress[0])
    return (nameMatching?.score ?? 1) + (addrMatching?.score ?? 1) * 2
}

func loadUrl(
    urlString: String,
    authentication: String?,
    onSuccess: @escaping(_ data: Data) -> Void,
    onError: @escaping(_ errorMessage: String) -> Void
    ) {
    let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
    logMessage("Loading URL: \(encodedUrlString)")
    guard let url = URL(string: encodedUrlString) else {
        logMessage("URL \(encodedUrlString) is not a valid url")
        onError("The inputs are invalid. Maybe remove from gibberish from your search term?")
        return
    }
    var request = URLRequest(url: url)
    if isNonEmptyString(authentication) {
        request.setValue(authentication, forHTTPHeaderField: "Authorization")
    }
    let task = URLSession.shared.dataTask(with: request, completionHandler: {
        (data:Data?, response:URLResponse?, error:Error?) -> Void in
        if let error = error {
            logMessage("\(error)")
            onError("Oops! A network error occurred on search.")
            return
        }
        let httpResponse = response as? HTTPURLResponse
        if httpResponse == nil || (200...299).contains(httpResponse!.statusCode) == false {
            logMessage("A network error occurred when loading URL. Status code: \(httpResponse!.statusCode)")
            if (400...499).contains(httpResponse!.statusCode) {
                onError("Oops! A network error occurred on search... Can you check if you're online?")
            } else { // 500+
                onError("Oops! The site you are searching with is down... please try again later or use another site.")
            }
            return
        }
        if let mimeType = httpResponse?.mimeType, mimeType == "application/json",
            let data = data {
            onSuccess(data)
        }
    })
    task.resume()
}
