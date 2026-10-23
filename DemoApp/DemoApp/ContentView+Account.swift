/*
    Copyright (c) 2026 Nicolas GONZALEZ

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
    documentation files (the “Software”), to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLteDERS BE
    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
    IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI
import AVKit
import Gzip
import OSLog

// Account: sign-in and sign-out, registration, passwords, account and email
// changes, the forms' errors and resets, the Keychain credentials
extension ContentView {
    func submitAccountForm() {
        do {
            let user = UserWithAccount(
                id: self.signedInUser?.id,
                accountUuid: self.signedInUser?.accountUuid,
                accountName: accountNameAccountForm,
                accountAddress: accountAddressAccountForm,
                firstName: firstNameAccountForm,
                lastName: lastNameAccountForm,
                emailAddress: emailAddressAccountForm,
                emailAddressValidatedAt: "",
                password: "",
                deliverNotificationsSignIn: notifyOnSignInAccountForm,
                deliverNotificationsAccountUpdate: notifyOnAccountUpdateAccountForm,
                createdAt: self.signedInUser?.createdAt,
                updatedAt: self.signedInUser?.updatedAt,
                errors: nil,
                subdomain: subdomainAccountForm.trimmingCharacters(in: .whitespaces).lowercased()
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(userURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                                // callback
                                self.signedInUser = userResponseWithMessage.user
                                resetValuesEditAccount(keep_values: true)
                                handleEmailChange(user: user)
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditAccount(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editAccountSuccessMessage = message
                        }
                    }
                } catch let error {
                    logger.error("[submitAccountForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitAccountForm] Error: \(error)")
        }
    }

    func iterateOverErrorsAccountCode(errors: [String?]) {
        self.accountCodeValidationErrors = String()
        errors.forEach { error in
            accountCodeValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsNewSession(errors: [String?]) {
        self.newSessionValidationErrors = String()
        errors.forEach { error in
            newSessionValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditAccount(errors: [String?]) {
        self.editAccountValidationErrors = String()
        errors.forEach { error in
            editAccountValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsNewAccount(errors: [String?]) {
        self.newAccountValidationErrors = String()
        errors.forEach { error in
            newAccountValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsNewPassword(errors: [String?]) {
        self.newPasswordValidationErrors = String()
        errors.forEach { error in
            newPasswordValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditPassword(errors: [String?]) {
        self.editPasswordValidationErrors = String()
        errors.forEach { error in
            editPasswordValidationErrors += "\n▫️\(error!)"
        }
    }

    func iterateOverErrorsEditEmailAddress(errors: [String?]) {
        self.editEmailAddressValidationErrors = String()
        errors.forEach { error in
            editEmailAddressValidationErrors += "\n▫️\(error!)"
        }
    }

    func submitRegistrationForm() {
        let passwordProblems = PasswordRules.problems(passwordRegistrationForm, emailAddress: emailAddressRegistrationForm)
        guard passwordProblems.isEmpty else {
            iterateOverErrorsNewAccount(errors: passwordProblems)
            return
        }
        do {
            let user = UserWithAccount(
                id: nil,
                accountUuid: self.registrationAccount?.uuid,
                accountName: "",
                accountAddress: "",
                firstName: firstNameRegistrationForm,
                lastName: lastNameRegistrationForm,
                emailAddress: emailAddressRegistrationForm,
                emailAddressValidatedAt: "",
                password: passwordRegistrationForm,
                deliverNotificationsSignIn: false,
                deliverNotificationsAccountUpdate: false,
                createdAt: nil,
                updatedAt: nil,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(registrationURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)
                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                                // callback
                                resetValuesNewAccount(keep_values: true)
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsNewAccount(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.newAccountSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitRegistrationForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitRegistrationForm] Error: \(error)")
        }
    }

    // GET /accounts?accountCode=: the account to register in
    func submitAccountCode(accountCode: String) {
        var components = URLComponents(string: accountsURL)!
        components.queryItems = [URLQueryItem(name: "accountCode", value: accountCode)]
        let url = components.url!
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newGetRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let accountResponseWithMessage = try JSONDecoder().decode(AccountResponseWithMessage.self, from: data!)

                DispatchQueue.main.async {

                    // handle response
                    let httpResponse = response as? HTTPURLResponse
                    let httpResponseUnwrapped = httpResponse!
                    let errorsData = accountResponseWithMessage.account?.errors!
                    if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                        // callback
                        self.registrationAccount = accountResponseWithMessage.account
                    } else if errorsData != nil {
                        let errorsDataUnwrapped = errorsData!
                        iterateOverErrorsAccountCode(errors: errorsDataUnwrapped)
                    }

                    // validation message
                    if (accountResponseWithMessage.message != nil) {
                        let message = Message(message: accountResponseWithMessage.message)
                        logger.info("\(message.message!)")
                        self.accountCodeSuccessMessage = message
                    }
                }

            } catch let error {
                logger.error("[submitAccountCode] Request: \(error)")
            }
        }

        task.resume()
    }

    // Save the signed-in user's email address and password in the keychain
    // for `server`, read again at launch (readCredentials): update the item
    // when there is one, add it the first time
    func storeCredentials(username: String, password: String, server: String) {
        self.userCredentials = Credentials(account: username, password: password)
        guard !username.isEmpty, !password.isEmpty else { return }

        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server]
        let attributes: [String: Any] = [kSecAttrAccount as String: username,
                                         kSecValueData as String: Data(password.utf8)]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = query.merging(attributes) { _, new in new }
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func readCredentials(server: String) -> Credentials {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrServer as String: server,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]

        var item: CFTypeRef?
        _ = SecItemCopyMatching(query as CFDictionary, &item)
        let existingItem = item as? [String : Any]
        if (item != nil) {
            let account = existingItem?[kSecAttrAccount as String] as? String
            let passwordData = existingItem![kSecValueData as String] as! Data
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
            let accountUnwrapped = account!
            let passwordUnwrapped = password!
            return Credentials(account: accountUnwrapped, password: passwordUnwrapped)
        } else {
            return Credentials(account: "", password: "")
        }
    }

    func submitNewSessionForm() {
        do {
            let user = UserWithEmailAddressAndPassword(
                id: nil,
                emailAddress: emailAddressSessionForm,
                password: passwordSessionForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(sessionURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        let errorsData = userResponseWithMessage.user?.errors!
                        if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                            // callback
                            self.signedInUser = userResponseWithMessage.user
                            if (self.signedInUser?.emailAddressValidatedAt != nil) {
                                self.identified = true
                                resetValuesNewSession(keep_values: false)
                                storeCredentials(
                                    username: user.emailAddress!,
                                    password: user.password!,
                                    server: "appshare.site"
                                )
                            }
                        } else if errorsData != nil {
                            let errorsDataUnwrapped = errorsData!
                            iterateOverErrorsNewSession(errors: errorsDataUnwrapped)
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            logger.info("\(message.message!)")
                            self.newSessionSuccessMessage = message
                        }
                    }

                    DispatchQueue.main.async {
                        getAllUploads()
                    }

                } catch let error {
                    logger.error("[submitNewSessionForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitNewSessionForm] Error: \(error)")
        }
    }

    func submitDestroySessionForm() {
        let url = URL(string: "\(sessionURL)")!
        let delegateClass = NetworkDelegateClass()
        let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
        let request = newDeleteRequest(url: url)
        let task = delegateSession.dataTask(with: request) { data, response, error in
            do {
                let message = try JSONDecoder().decode(Message.self, from: data!)

                DispatchQueue.main.async {

                    // handle response
                    let httpResponse = response as? HTTPURLResponse
                    let httpResponseUnwrapped = httpResponse!
                    if (httpResponseUnwrapped.statusCode == 200) {

                        // callback
                        self.destroySessionFormResponse = message
                        self.signedInUser = nil
                        self.identified = false
                        self.newSession = true
                        self.newSessionComplete = false
                        clearSelectedFolders()
                        self.loadedFolders = Array<Folder>()
                        self.selectedFolders = Set()
                    }
                }

            } catch let error {
                logger.error("[submitDestroySessionForm] Request: \(error)")
            }
        }

        task.resume()
    }

    func submitNewPasswordForm() {
        do {
            let user = UserWithEmailAddress(
                id: nil,
                emailAddress: emailAddressPasswordForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(passwordURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPostRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        if (userResponseWithMessage.user != nil) {
                            if (httpResponseUnwrapped.statusCode == 200) {

                                // callback
                                resetValuesNewPassword(keep_values: true)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.newPasswordSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitNewPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitNewPasswordForm] Error: \(error)")
        }
    }

    func submitEditPasswordForm() {
        let passwordProblems = PasswordRules.problems(newPasswordEditPasswordForm, emailAddress: self.signedInUser?.emailAddress ?? "")
        guard passwordProblems.isEmpty else {
            iterateOverErrorsEditPassword(errors: passwordProblems)
            return
        }
        do {
            let user = UserWithPasswordAndPasswordConfirmation(
                id: self.signedInUser?.id,
                password: newPasswordEditPasswordForm,
                passwordConfirmation: newPasswordConfirmationEditPasswordForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(passwordURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                                // callback
                                resetValuesEditPassword(keep_values: true)
                                storeCredentials(
                                    username: self.userCredentials.account,
                                    password: user.password!,
                                    server: "appshare.site"
                                )
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditPassword(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editPasswordSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitEditPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitEditPasswordForm] Error: \(error)")
        }
    }

    func submitEditEmailAddressForm() {
        do {
            let user = UserWithEmailAddressAndNewEmailAddress(
                id: self.signedInUser?.id,
                emailAddress: newEmailAddressEditEmailAddressForm,
                errors: nil
            )

            let data = try JSONEncoder().encode(user)
            let url = URL(string: "\(emailURL)")!
            let delegateClass = NetworkDelegateClass()
            let delegateSession = URLSession(configuration: .default, delegate: delegateClass, delegateQueue: nil)
            let optimizedData: Data = try! data.gzipped(level: .bestCompression)
            let postLength = String(format: "%lu", UInt(optimizedData.count))
            let request = newPutRequest(url: url, data: optimizedData, postLength: postLength)
            let task = delegateSession.dataTask(with: request) { data, response, error in
                do {
                    let userResponseWithMessage = try JSONDecoder().decode(UserResponseWithMessage.self, from: data!)

                    DispatchQueue.main.async {

                        // handle response
                        let httpResponse = response as? HTTPURLResponse
                        let httpResponseUnwrapped = httpResponse!
                        if (userResponseWithMessage.user != nil) {
                            let errorsData = userResponseWithMessage.user?.errors!
                            if (errorsData == [] && httpResponseUnwrapped.statusCode == 200) {

                                // callback
                                resetValuesEditEmailAddress(keep_values: true)
                                storeCredentials(
                                    username: user.emailAddress!,
                                    password: self.userCredentials.password,
                                    server: "appshare.site"
                                )
                                emailAddressSessionForm = user.emailAddress!
                                passwordSessionForm = self.userCredentials.password
                            } else {
                                let errorsDataUnwrapped = errorsData!
                                iterateOverErrorsEditEmailAddress(errors: errorsDataUnwrapped)
                            }
                        }

                        // validation message
                        if (userResponseWithMessage.message != nil) {
                            let message = Message(message: userResponseWithMessage.message)
                            self.editEmailAddressSuccessMessage = message
                        }
                    }

                } catch let error {
                    logger.error("[submitEditPasswordForm] Request: \(error)")
                }
            }

            task.resume()

        } catch let error {
            logger.error("[submitEditPasswordForm] Error: \(error)")
        }
    }

    func clickRegisterLink() {
        self.newAccount = true
    }

    func clickPasswordLink() {
        self.newPassword = true
    }

    func clickBackToAccountLink() {
        backToMyAccount()
    }

    func clickSigninLink() {
        // enable new session
        self.newSession = true

        // disable other sections
        self.myAccount = false
        self.newAccount = false
        self.editAccount = false
        self.editEmailAddress = false
        self.editPassword = false
        self.newPassword = false

        // reset forms
        resetFieldsNewAccount(keep_values: false)
        resetFieldsNewPassword(keep_values: false)
        resetFieldsNewSession(keep_values: false)

        // enable buttons again
        self.newAccountComplete = false
        self.editAccountComplete = false
        self.editEmailAddressComplete = false
        self.editPasswordComplete = false
        self.newPasswordComplete = false
        self.newSessionComplete = false
    }

    func backToMyAccount() {
        // enable my account
        self.myAccount = true

        // disable other sections
        self.newAccount = false
        self.editAccount = false
        self.editEmailAddress = false
        self.editPassword = false
        self.newPassword = false
        self.newSession = false

        // reset forms
        resetValuesNewAccount(keep_values: false)
        resetValuesEditAccount(keep_values: false)
        resetValuesEditEmailAddress(keep_values: false)
        resetValuesEditPassword(keep_values: false)
        resetValuesNewPassword(keep_values: false)
        resetValuesNewSession(keep_values: false)

        // enable buttons again
        self.newAccountComplete = false
        self.editAccountComplete = false
        self.editEmailAddressComplete = false
        self.editPasswordComplete = false
        self.newPasswordComplete = false
        self.newSessionComplete = false
    }

    func clickEditAccount() {
        self.editAccount = true

        let accountName = self.signedInUser?.accountName
        if (accountName != nil) {
            let accountNameUnWrapped = accountName!
            self.accountNameAccountForm = accountNameUnWrapped
        }
        let accountAddress = self.signedInUser?.accountAddress
        if (accountAddress != nil) {
            let accountAddressUnWrapped = accountAddress!
            self.accountAddressAccountForm = accountAddressUnWrapped
        }
        self.subdomainAccountForm = self.signedInUser?.accountSubdomain ?? String()
        let firstName = self.signedInUser?.firstName
        if (firstName != nil) {
            let firstNameUnWrapped = firstName!
            self.firstNameAccountForm = firstNameUnWrapped
        }
        let lastName = self.signedInUser?.lastName
        if (lastName != nil) {
            let lastNameUnWrapped = lastName!
            self.lastNameAccountForm = lastNameUnWrapped
        }
        let emailAddress = self.signedInUser?.emailAddress
        if (emailAddress != nil) {
            let emailAddressUnWrapped = emailAddress!
            self.emailAddressAccountForm = emailAddressUnWrapped
        }
        let notifyOnSignIn = self.signedInUser?.deliverNotificationsSignIn
        if (notifyOnSignIn != nil) {
            let notifyOnSignInUnWrapped = notifyOnSignIn!
            self.notifyOnSignInAccountForm = notifyOnSignInUnWrapped
        }
        let notifyOnAccountUpdate = self.signedInUser?.deliverNotificationsAccountUpdate
        if (notifyOnAccountUpdate != nil) {
            let notifyOnAccountUpdateUnWrapped = notifyOnAccountUpdate!
            self.notifyOnAccountUpdateAccountForm = notifyOnAccountUpdateUnWrapped
        }
    }

    func clickEditPassword() {
        self.editPassword = true

        let password = self.signedInUser?.password
        if (password != nil) {
            let passwordUnwrapped = password!
            self.newPasswordEditPasswordForm = passwordUnwrapped
            self.newPasswordConfirmationEditPasswordForm = passwordUnwrapped
        }
    }

    func clickEditEmailAddress() {
        self.editEmailAddress = true

        let emailAddress = self.signedInUser?.emailAddress
        if (emailAddress != nil) {
            let emailAddressUnwrapped = emailAddress!
            self.emailAddressEditEmailAddressForm = emailAddressUnwrapped
        }
    }

    func handleEmailChange(user: UserWithAccount) {
        if (user.emailAddress != self.userCredentials.account) {
            storeCredentials(
                username: user.emailAddress!,
                password: self.userCredentials.password!,
                server: "appshare.site"
            )
            emailAddressSessionForm = user.emailAddress!
            passwordSessionForm = self.userCredentials.password!
        }
    }

    func resetValuesNewSession(keep_values: Bool?) {
//        self.newSession = false
        self.newSessionComplete = true

        self.myAccount = true
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        resetFieldsNewSession(keep_values: keep_values!)
    }

    func resetValuesNewPassword(keep_values: Bool?) {
//        self.newPassword = false
        self.newPasswordComplete = true

        self.newAccount = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        resetFieldsNewPassword(keep_values: keep_values!)
    }

    func resetValuesEditPassword(keep_values: Bool?) {
//        self.editPassword = false
        self.editPasswordComplete = true

        self.newAccount = false
        self.newPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        resetFieldsEditPassword(keep_values: keep_values!)
    }

    func resetValuesNewAccount(keep_values: Bool?) {
//        self.newAccount = false
        self.newAccountComplete = true

        self.newPassword = false
        self.editPassword = false
        self.editAccount = false
        self.editEmailAddress = false

        resetFieldsNewAccount(keep_values: keep_values!)
    }

    func resetValuesEditAccount(keep_values: Bool?) {
//        self.editAccount = false
        self.editAccountComplete = true

        self.newAccount = false
        self.newPassword = false
        self.editPassword = false
        self.editEmailAddress = false

        resetFieldsEditAccount(keep_values: keep_values!)
    }

    func resetValuesEditEmailAddress(keep_values: Bool?) {
//        self.editEmailAddress = false
        self.editEmailAddressComplete = true

        self.editAccount = false
        self.newAccount = false
        self.newPassword = false
        self.editPassword = false

        resetFieldsEditEmailAddress(keep_values: keep_values!)
    }

    func resetFieldsNewSession(keep_values: Bool) {
        // reset errors
        self.newSessionValidationErrors = String()

        // reset message
        self.newSessionSuccessMessage = Message(message: String())
        self.destroySessionFormResponse = Message(message: String())

        if (keep_values) {
            return
        } else {
            // reset values
            self.emailAddressSessionForm = String()
            self.passwordSessionForm = String()
        }
    }

    func resetFieldsNewPassword(keep_values: Bool) {
        // reset errors
        self.newPasswordValidationErrors = String()

        // reset message
        self.newPasswordSuccessMessage = Message(message: String())

        if (keep_values) {
            return
        } else {
            // reset values
            self.emailAddressPasswordForm = String()
        }
    }

    func resetFieldsNewAccount(keep_values: Bool) {
        // reset errors
        self.newAccountValidationErrors = String()
        self.accountCodeValidationErrors = String()

        // reset message
        self.newAccountSuccessMessage = Message(message: String())
        self.accountCodeSuccessMessage = Message(message: String())

        if (keep_values) {
            return
        } else {
            resetAccountCode()

            self.firstNameRegistrationForm = String()
            self.lastNameRegistrationForm = String()
            self.emailAddressRegistrationForm = String()
            self.passwordRegistrationForm = String()
            self.passwordConfirmationRegistrationForm = String()
        }
    }

    func resetAccountCode() {
        // registration account
        self.registrationAccount = nil

        // reset values
        self.accountCodeRegistrationForm = String()
        self.accountUuidRegistrationForm = String()
        self.accountNameRegistrationForm = String()
        self.accountAddressRegistrationForm = String()
    }

    func resetFieldsEditAccount(keep_values: Bool) {
        // reset errors
        self.editAccountValidationErrors = String()

        // reset message
        self.editAccountSuccessMessage = Message(message: String())

        if (keep_values) {
            return
        } else {
            // reset values
            self.accountNameAccountForm = String()
            self.accountAddressAccountForm = String()
            self.subdomainAccountForm = String()
            self.firstNameAccountForm = String()
            self.lastNameAccountForm = String()
            self.emailAddressAccountForm = String()

            // self.notifyOnSignInAccountForm = false
            // self.notifyOnAccountUpdateAccountForm = false
        }
    }

    func resetFieldsEditPassword(keep_values: Bool) {
        // reset errors
        self.editPasswordValidationErrors = String()

        // reset message
        self.editPasswordSuccessMessage = Message(message: String())

        if (keep_values) {
            return
        } else {
            // reset values
            self.newPasswordEditPasswordForm = String()
            self.newPasswordConfirmationEditPasswordForm = String()
        }
    }

    func resetFieldsEditEmailAddress(keep_values: Bool) {
        // reset errors
        self.editEmailAddressValidationErrors = String()

        // reset message
        self.editEmailAddressSuccessMessage = Message(message: String())

        if (keep_values) {
            return
        } else {
            // reset values
            self.newEmailAddressEditEmailAddressForm = String()
        }
    }
}
