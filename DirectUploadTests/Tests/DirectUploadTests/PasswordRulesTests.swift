import Testing
@testable import DirectUpload

/// The same cases as the backend's spec (User password rules)
@Suite struct PasswordRulesTests {
    @Test func acceptsTwelveCharactersWithALetterAndADigit() {
        #expect(PasswordRules.problems("correct-horse-7", emailAddress: "anna.smith@example.com").isEmpty)
    }

    @Test func refusesAShortPassword() {
        #expect(PasswordRules.problems("short-pass1", emailAddress: "anna.smith@example.com") == ["Password must have at least 12 characters"])
    }

    @Test func refusesAPasswordWithoutADigitOrALetter() {
        #expect(PasswordRules.problems("no-digits-in-here", emailAddress: "a@b.c") == ["Password must have at least one letter and one digit"])
        #expect(PasswordRules.problems("1234-5678-9012", emailAddress: "a@b.c") == ["Password must have at least one letter and one digit"])
    }

    @Test func refusesTheEmailAddressNameWhateverTheCase() {
        #expect(PasswordRules.problems("My-Anna.Smith-2026", emailAddress: "anna.smith@example.com") == ["Password must not contain your email address"])
    }

    @Test func ignoresAShortEmailAddressName() {
        #expect(PasswordRules.problems("an-ordinary-pass1", emailAddress: "an@example.com").isEmpty)
    }

    @Test func acceptsLettersWithAccents() {
        #expect(PasswordRules.problems("élève-motdepasse-3", emailAddress: "anna@example.com").isEmpty)
    }

    @Test func listsEveryProblem() {
        #expect(PasswordRules.problems("anna", emailAddress: "anna@example.com").count == 3)
    }
}
