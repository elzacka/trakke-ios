import Foundation

enum Levenshtein {
    static func distance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        let len1 = s1.count
        let len2 = s2.count

        if len1 == 0 { return len2 }
        if len2 == 0 { return len1 }

        var previousRow = Array(0...len2)
        var currentRow = [Int](repeating: 0, count: len2 + 1)

        for i in 1...len1 {
            currentRow[0] = i
            for j in 1...len2 {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }
            swap(&previousRow, &currentRow)
        }

        return previousRow[len2]
    }
}
