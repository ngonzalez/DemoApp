//
//  PasswordRules.swift
//  DemoApp
//

import Foundation

/// The backend's password rules (User#password_strength), checked before a
/// password is sent: at least 12 characters, a letter and a digit, and not
/// the name of the email address (before the @, 3 letters or more)
enum PasswordRules {
    static let minimumLength = 12

    /// What is wrong with a password, empty when it follows the rules
    static func problems(_ password: String, emailAddress: String) -> [String] {
        var problems: [String] = []
        if password.count < minimumLength {
            problems.append("Password must have at least \(minimumLength) characters")
        }
        if !password.contains(where: \.isLetter) || !password.contains(where: \.isNumber) {
            problems.append("Password must have at least one letter and one digit")
        }
        let name = (emailAddress.split(separator: "@").first.map(String.init) ?? "").lowercased()
        if name.count >= 3 && password.lowercased().contains(name) {
            problems.append("Password must not contain your email address")
        }
        return problems
    }
}
