import Foundation

enum NHSNumberValidator {
    static func isValid(number: String) -> Bool {
        let digits = number.filter { $0.isNumber }
        guard digits.count == 10 else { return false }
        var total = 0
        for (index, character) in digits.enumerated().dropLast() {
            guard let value = character.wholeNumberValue else { return false }
            let weight = 10 - index
            total += value * weight
        }
        let checkDigit = (11 - (total % 11)) % 11
        guard checkDigit != 10, let last = digits.last?.wholeNumberValue else {
            return false
        }
        return checkDigit == last
    }
}
