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

// Account's part of the window
extension ContentView {
    // Account, middle column: sign-in, registration, password, My Account and its forms
    @ViewBuilder
    var accountPanel: some View {
        if self.identified {
            if self.editPassword {
                /*
                    Account: Edit Password
                */
                Form {
                    VStack {
                        Spacer()

                        Text("Change Password")
                            .font(.system(size: 15))

                        if let message = editPasswordSuccessMessage.message {
                            Text("\(message)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        Text("\(editPasswordValidationErrors)\n")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)

                        SecureField(text: $newPasswordEditPasswordForm, prompt: Text("New Password")) {
                            Text("New Password")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.editPasswordComplete)

                        SecureField(text: $newPasswordConfirmationEditPasswordForm, prompt: Text("New Password confirmation")) {
                            Text("New Password confirmation")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.editPasswordComplete)

                        Button(action: submitEditPasswordForm) {
                            Text("Submit")
                        }
//                                .buttonStyle(PlainButtonStyle())
                        .disabled(self.editPasswordComplete)
                        .font(.system(size: 11))
                        .padding(5)
                        .opacity(0.9)
                        .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                        .buttonStyle(.glassProminent)

                        Spacer()

                        Divider()

                        /* Account */
                        Button(action: clickBackToAccountLink) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 20))
                            Text("Back to my account")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)

            } else if self.editEmailAddress {
                /*
                    Account: Edit Email Address
                */
                Form {
                    VStack {
                        Spacer()

                        Text("Change email address")
                            .font(.system(size: 15))

                        if let message = editEmailAddressSuccessMessage.message {
                            Text("\(message)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        Text("\(editEmailAddressValidationErrors)\n")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)

                        let emailAddress = self.signedInUser?.emailAddress
                        let emailAddressUnwrapped = emailAddress!
                        TextField(text: $emailAddressEditEmailAddressForm, prompt: Text("\(emailAddressUnwrapped)")) {
                            Text("Current Email Address")
                        }
                        .disableAutocorrection(true)
//                                .disabled(self.editEmailAddressComplete)
                        .disabled(true)

                        TextField(text: $newEmailAddressEditEmailAddressForm) {
                            Text("New Email Address")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.editEmailAddressComplete)

                        Button(action: submitEditEmailAddressForm) {
                            Text("Submit")
                        }
//                                .buttonStyle(PlainButtonStyle())
                        .disabled(self.editEmailAddressComplete)
                        .font(.system(size: 11))
                        .padding(5)
                        .opacity(0.9)
                        .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                        .buttonStyle(.glassProminent)

                        Spacer()

                        Divider()

                        /* Account */
                        Button(action: clickBackToAccountLink) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 20))
                            Text("Back to my account")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)

            } else if self.editAccount {
                /*
                    Account: Edit Account
                */
                Form {
                    VStack {
                        Spacer()

                        Text("Edit User Account")
                            .font(.system(size: 15))

                        if let message = editAccountSuccessMessage.message {
                            Text("\(message)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        Text("\(editAccountValidationErrors)\n")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)

                        let accountUuid = self.signedInUser?.accountUuid!.uuidString
                        if (accountUuid != nil) {
                            let accountUuidUnWrapped:String = accountUuid!
                            TextField(text: $accountUuidAccountForm, prompt: Text(accountUuidUnWrapped)) {
                                Text("Account UUID")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        let accountName = self.signedInUser?.accountName
                        if (accountName != nil) {
                            let accountNameUnWrapped:String = accountName!
                            TextField(text: $accountNameAccountForm, prompt: Text(accountNameUnWrapped)) {
                                Text("Account Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        // the address of the account's site, shown only: it can't be
                        // changed from here
                        HStack {
                            TextField(text: $subdomainAccountForm, prompt: Text("Address of your site")) {
                                Text("Address of your site")
                            }
                            .disableAutocorrection(true)
                            .textContentType(.none)
                            .disabled(true)
                            Text(".appshare.site")
                                .foregroundStyle(.secondary)
                        }

                        let accountAddress = self.signedInUser?.accountAddress
                        if (accountAddress != nil) {
                            let accountAddressUnWrapped:String = accountAddress!
                            TextField(text: $accountAddressAccountForm, prompt: Text(accountAddressUnWrapped)) {
                                Text("Address")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        let firstName = self.signedInUser?.firstName
                        if (firstName != nil) {
                            let firstNameUnWrapped:String = firstName!
                            TextField(text: $firstNameAccountForm, prompt: Text(firstNameUnWrapped)) {
                                Text("First Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.editAccountComplete)
                        }

                        let lastName = self.signedInUser?.lastName
                        if (lastName != nil) {
                            let lastNameUnWrapped:String = lastName!
                            TextField(text: $lastNameAccountForm, prompt: Text(lastNameUnWrapped)) {
                                Text("Last Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.editAccountComplete)
                        }

                        let emailAddress = self.signedInUser?.emailAddress
                        if (emailAddress != nil) {
                            let emailAddressUnWrapped:String = emailAddress!
                            TextField(text: $emailAddressAccountForm, prompt: Text(emailAddressUnWrapped)) {
                                Text("Email Address")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.editAccountComplete)
                        }

                        let createdAt = self.signedInUser?.createdAt
                        if (createdAt != nil) {
                            let createdAtUnwrapped = createdAt!
                            TextField(text: $createdAtAccountForm, prompt: Text(createdAtUnwrapped)) {
                                Text("Created At")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        let updatedAt = self.signedInUser?.updatedAt
                        if (updatedAt != nil) {
                            let updatedAtUnwrapped = updatedAt!
                            TextField(text: $updatedAtAccountForm, prompt: Text(updatedAtUnwrapped)) {
                                Text("Updated At")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        Spacer()

                        let notifyOnSignIn = self.signedInUser?.deliverNotificationsSignIn
                        if (notifyOnSignIn != nil) {
                            Toggle(
                                "Notify me when I sign-in",
                                isOn: $notifyOnSignInAccountForm
                            )
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(self.editAccountComplete)
                        }

                        let notifyOnAccountUpdate = self.signedInUser?.deliverNotificationsAccountUpdate
                        if (notifyOnAccountUpdate != nil) {
                            Toggle(
                                "Notify me when my account is updated",
                                isOn: $notifyOnAccountUpdateAccountForm
                            )
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .disabled(self.editAccountComplete)
                        }

                        Spacer()

                        Button(action: submitAccountForm) {
                            Text("Submit")
                        }
//                                .buttonStyle(PlainButtonStyle())
                        .disabled(self.editAccountComplete)
                        .font(.system(size: 11))
                        .padding(5)
                        .opacity(0.9)
                        .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                        .buttonStyle(.glassProminent)

                        Spacer()

                        Divider()

                        /* Account */
                        Button(action: clickBackToAccountLink) {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 20))
                            Text("Back to my account")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)

            } else if self.myAccount {
                /*
                    Account Panel
                */
                Text("My Account")
                    .font(.system(size: 15))

                if #available(macOS 15.0, *) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .symbolEffect(.bounce, options: .repeat(1))
                        .padding(10)
                } else {
                    Image(systemName: "person.circle")
                        .font(.system(size: 20))
                        .padding(10)
                }

                /* User Email */
                let emailAddress = self.signedInUser?.emailAddress
                if (emailAddress != nil) {
                    let emailAddressUnWrapped:String = emailAddress!
                    Text(emailAddressUnWrapped)
                        .padding(10)
                }

                /* Account usage, below the email address */
                accountUsage

                /* Edit Account, Edit Password, Edit Email Address: buttons of the same width */
                VStack(spacing: 8) {
                    Button(action: clickEditAccount) {
                        Label("Edit account", systemImage: "person.text.rectangle")
                            .frame(maxWidth: .infinity)
                    }

                    Button(action: clickEditPassword) {
                        Label("Change password", systemImage: "key")
                            .frame(maxWidth: .infinity)
                    }

                    Button(action: clickEditEmailAddress) {
                        Label("Change email address", systemImage: "envelope")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .frame(width: 260)
                .padding(.top, 6)
          }

        } else if self.newPassword {
            /*
                Account: Reset Password
            */
            Form {
                VStack {
                    Spacer()

                    Text("Reset Password")
                        .font(.system(size: 15))

                    if let message = newPasswordSuccessMessage.message {
                        Text("\(message)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Text("\(newPasswordValidationErrors)\n")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)

                    TextField(text: $emailAddressPasswordForm, prompt: Text("johnatan@apple.com")) {
                        Text("Email")
                    }
                    .disableAutocorrection(true)
                    .disabled(self.newPasswordComplete)

                    Button(action: submitNewPasswordForm) {
                        Text("Submit")
                    }
//                            .buttonStyle(PlainButtonStyle())
                    .disabled(self.newPasswordComplete)
                    .font(.system(size: 11))
                    .padding(5)
                    .opacity(0.9)
                    .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                    .buttonStyle(.glassProminent)

                    Spacer()

                    Divider()

                    /* Signin */
                    Button(action: clickSigninLink) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 20))
                        Text("Back to Sign-In")
                            .foregroundStyle(.blue.gradient)
                    }.buttonStyle(PlainButtonStyle())
                }
                .textFieldStyle(.roundedBorder)
            }.padding(20)

        } else if self.newAccount {
            /*
                Account: Registration
            */
            Form {
                VStack {
                    Spacer()

                    Text("Register Account")
                        .font(.system(size: 15))

                    if let message = newAccountSuccessMessage.message {
                        Text("\(message)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }

                    Text("\(newAccountValidationErrors)\n")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)

//                            if let message = accountCodeSuccessMessage.message {
//                                Text("\(message)")
//                                    .font(.system(size: 11))
//                                    .foregroundStyle(Color.secondary)
//                            }

                    Text("\(accountCodeValidationErrors)\n")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)

                    TextField(text: $accountCodeRegistrationForm, prompt: Text("Account Code")) {
                        Text("Account Code")
                    }
                    .disableAutocorrection(true)
                    .disabled(self.newAccountComplete)
                    .onChange(of: accountCodeRegistrationForm) { _, value in
                        if (value == "") {
                            resetAccountCode()
                        } else {
                            submitAccountCode(accountCode: value)
                        }
                    }

                    let accountUuid = self.registrationAccount?.uuid!.uuidString
                    if (accountUuid != nil) {
                        let accountUuidUnwrapped:String = accountUuid!
                        TextField(text: $accountUuidRegistrationForm, prompt: Text(accountUuidUnwrapped)) {
                            Text("Account UUID")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.newAccountComplete)
                        .disabled(true)
                    }

                    let accountName = self.registrationAccount?.name
                    if (accountName != nil) {
                        let accountNameUnwrapped:String = accountName!
                        TextField(text: $accountNameRegistrationForm, prompt: Text(accountNameUnwrapped)) {
                            Text("Account Name")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.newAccountComplete)
                        .disabled(true)
                    }

                    let accountAddress = self.registrationAccount?.address
                    if (accountAddress != nil) {
                        let accountAddressUnwrapped:String = accountAddress!
                        TextField(text: $accountAddressRegistrationForm, prompt: Text(accountAddressUnwrapped)) {
                            Text("Account Address")
                        }
                        .disableAutocorrection(true)
                        .disabled(self.newAccountComplete)
                        .disabled(true)
                    }

                    Divider()

                    TextField(text: $firstNameRegistrationForm, prompt: Text("John")) {
                        Text("First Name")
                    }
                    .disableAutocorrection(true)
                    .disabled(self.newAccountComplete)

                    TextField(text: $lastNameRegistrationForm, prompt: Text("Appleseed")) {
                        Text("Last Name")
                    }
                    .disableAutocorrection(true)
                    .disabled(self.newAccountComplete)

                    TextField(text: $emailAddressRegistrationForm, prompt: Text("johnatan@apple.com")) {
                        Text("Email")
                    }
                    // AutoFill: the account of the password the Passwords app saves
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .disabled(self.newAccountComplete)

                    SecureField(text: $passwordRegistrationForm, prompt: Text("Required")) {
                        Text("Password")
                    }
                    // No .newPassword AutoFill hint: its strong password panel swallowed
                    // the first click on Submit
                    .disableAutocorrection(true)
                    .disabled(self.newAccountComplete)

//                            SecureField(text: $passwordConfirmationRegistrationForm, prompt: Text("Required")) {
//                                Text("Password Confirmation")
//                            }
//                            .disableAutocorrection(true)
//                            .disabled(self.newAccountComplete)

                    Button(action: submitRegistrationForm) {
                        Text("Submit")
                    }
//                            .buttonStyle(PlainButtonStyle())
                    .disabled(self.newAccountComplete)
                    .font(.system(size: 11))
                    .padding(5)
                    .opacity(0.9)
                    .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                    .buttonStyle(.glassProminent)

                    Spacer()

                    Divider()

                    /* Signin */
                    Button(action: clickSigninLink) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 20))
                        Text("Back to Sign-In")
                            .foregroundStyle(.blue.gradient)
                    }.buttonStyle(PlainButtonStyle())
                }
                .textFieldStyle(.roundedBorder)
            }.padding(20)

        } else if self.newSession {
            /*
                Account: Sign-In
            */
            Form {
                VStack {
                    Spacer()

                    Text("New Session")
                        .font(.system(size: 15))

                    Text("\(newSessionValidationErrors)\n")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)

                    TextField(text: $emailAddressSessionForm, prompt: Text("johnatan@apple.com")) {
                        Text("Email")
                    }
                    // AutoFill: offers the passwords saved for appshare.site in the
                    // Passwords app (webcredentials in DemoApp.entitlements and the
                    // site's apple-app-site-association)
                    .textContentType(.username)
                    .disableAutocorrection(true)
                    .disabled(self.newSessionComplete)

                    SecureField(text: $passwordSessionForm, prompt: Text("Required")) {
                        Text("Password")
                    }
                    .textContentType(.password)
                    .disableAutocorrection(true)
                    .disabled(self.newSessionComplete)

                    Button(action: submitNewSessionForm) {
                        Text("Submit")
                    }
//                            .buttonStyle(PlainButtonStyle())
                    .disabled(self.newSessionComplete)
                    .font(.system(size: 11))
                    .padding(5)
                    .opacity(0.9)
                    .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(KeyboardShortcut(.return, modifiers: []))

                    /* Register */
                    Button(action: clickRegisterLink) {
                        if #available(macOS 15.0, *) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 20))
                                .symbolEffect(.bounce, options: .repeat(1))
                                .padding(10)
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 20))
                                .padding(10)
                        }
                        Text("Register for a new account")
                            .foregroundStyle(.blue.gradient)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(30)

                    Spacer()

                    Divider()

                    /* Forgot Password */
                    Button(action: clickPasswordLink) {
                        Image(systemName: "mail")
                            .font(.system(size: 20))
                        Text("Forgot my password")
                            .foregroundStyle(.blue.gradient)
                    }.buttonStyle(PlainButtonStyle())
                }
                .textFieldStyle(.roundedBorder)

            }.padding(20)
        }

    }

    // Account, middle column, under the panel: the sign-out button
    @ViewBuilder
    var signOutPanel: some View {
        /*
          Account: Sign-Out
        */
        if self.identified && self.myAccount && (!self.newPassword && !self.editPassword && !self.editEmailAddress && !self.newAccount && !self.editAccount) {
            Button(action: submitDestroySessionForm) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.primary)
                Text("Sign-out")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    // My Account: the account's plan and what it uses of it (GET /account),
    // read again each time the page opens
    var accountUsage: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let plan = planUsage {
                Text("Account usage")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(plan.name) plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Storage: \(PlanUsage.size(plan.storage.used)) of \(PlanUsage.size(plan.storage.limit))")
                    .font(.caption)
                ProgressView(value: plan.storageFraction)
                    .tint(plan.storage.used >= plan.storage.limit ? .red : .accentColor)

                Text("Users: \(plan.users.count) of \(plan.users.limit)")
                    .font(.caption)
                ProgressView(value: Double(min(plan.users.count, plan.users.limit)), total: Double(max(plan.users.limit, 1)))
                    .tint(plan.users.count >= plan.users.limit ? .red : .accentColor)
            }
        }
        .frame(width: 260)
        .padding(10)
        .task {
            planUsage = await PlanUsage.fetch()
        }
    }
}

