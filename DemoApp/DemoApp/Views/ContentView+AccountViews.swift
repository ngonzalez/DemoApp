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
    // Account, middle column: sign-in, password, and My Account with the
    // buttons opening its forms (in the detail column, accountFormPanel)
    @ViewBuilder
    var accountPanel: some View {
        if self.identified {
            if self.myAccount {
                /*
                    Account Panel
                */
                Text("My Account")
                    .font(.system(size: 15))

                /* User Picture */
                signedInUserAvatar(size: 48)
                    .padding(10)

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

                    Button(action: clickInviteUsers) {
                        Label("Invite users", systemImage: "person.badge.plus")
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
                    .padding(.top, 30)

                    Text("Invited to an account? Use the link in your invitation email.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom, 30)

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

    // Account, detail column: the form a My Account button opened (one at a
    // time, see openAccountForm)
    @ViewBuilder
    var accountFormPanel: some View {
        if self.identified && self.myAccount {
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

                        /* Close the form */
                        Button(action: clickCloseAccountForm) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                            Text("Close")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)

            } else if self.inviteUsers {
                /*
                    Account: Invite Users
                */
                Form {
                    VStack {
                        Spacer()

                        Text("Invite users")
                            .font(.system(size: 15))

                        Text("Send an invitation to join this account by email.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)

                        if let message = inviteUsersSuccessMessage.message {
                            Text("\(message)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        Text("\(inviteUsersValidationErrors)\n")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)

                        TextField(text: $emailAddressInviteUsersForm, prompt: Text("Email Address")) {
                            Text("Email Address")
                        }
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                        .disabled(self.inviteUsersSending)

                        Button(action: submitInviteUsersForm) {
                            Text("Send invitation")
                        }
                        .disabled(self.inviteUsersSending)
                        .font(.system(size: 11))
                        .padding(5)
                        .opacity(0.9)
                        .glassEffect(.regular.tint(.clear).interactive(), in: .capsule)
                        .buttonStyle(.glassProminent)

                        Spacer()

                        Divider()

                        /* Close the form */
                        Button(action: clickCloseAccountForm) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                            Text("Close")
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

                        /* Close the form */
                        Button(action: clickCloseAccountForm) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                            Text("Close")
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

                        /* Picture: sent as soon as it's chosen */
                        avatarAccountForm

                        if let message = editAccountSuccessMessage.message {
                            Text("\(message)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.secondary)
                        }

                        Text("\(editAccountValidationErrors)\n")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)

                        let accountName = self.signedInUser?.accountName
                        if (accountName != nil) {
                            let accountNameUnWrapped:String = accountName!
                            TextField(text: $accountNameAccountForm, prompt: Text(accountNameUnWrapped)) {
                                Text("Account Name")
                            }
                            .disableAutocorrection(true)
                            .disabled(self.editAccountComplete)
                        }

                        // the address of the account's site, shown only: it can't be
                        // changed from here (shown as the prompt, which stays as bright
                        // as the editable fields; a disabled field's text is dimmed)
                        HStack {
                            TextField(text: .constant(String()), prompt: Text(subdomainAccountForm).foregroundStyle(.primary.opacity(0.7))) {
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
                            .disabled(self.editAccountComplete)
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
                            TextField(text: $createdAtAccountForm, prompt: Text(createdAtUnwrapped).foregroundStyle(.primary.opacity(0.7))) {
                                Text("Created At")
                            }
                            .disableAutocorrection(true)
                            .disabled(true)
                        }

                        let updatedAt = self.signedInUser?.updatedAt
                        if (updatedAt != nil) {
                            let updatedAtUnwrapped = updatedAt!
                            TextField(text: $updatedAtAccountForm, prompt: Text(updatedAtUnwrapped).foregroundStyle(.primary.opacity(0.7))) {
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

                        /* Close the form */
                        Button(action: clickCloseAccountForm) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 20))
                            Text("Close")
                                .foregroundStyle(.blue.gradient)
                        }.buttonStyle(PlainButtonStyle())
                    }
                    .textFieldStyle(.roundedBorder)
                }.padding(20)
            }
        }
    }

    // Account, middle column, under the panel: the sign-out button
    @ViewBuilder
    var signOutPanel: some View {
        /*
          Account: Sign-Out
        */
        if self.identified && self.myAccount {
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

    // The signed-in user's picture, or their initials
    func signedInUserAvatar(size: CGFloat) -> some View {
        UserAvatar(
            avatarUrl: self.signedInUser?.avatarUrl,
            firstName: self.signedInUser?.firstName,
            lastName: self.signedInUser?.lastName,
            size: size
        )
    }

    // Edit Account, top of the form: the picture, Choose Picture… (a file,
    // uploaded at once), Remove Picture (when there is one) and the presets
    // (hidden when GET /avatars/presets fails)
    var avatarAccountForm: some View {
        VStack(spacing: 8) {
            signedInUserAvatar(size: 80)
                .opacity(self.avatarSendingAccountForm ? 0.5 : 1)
                .overlay {
                    if self.avatarSendingAccountForm {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

            HStack {
                Button(action: {
                    isImportingAvatarAccountForm = true
                }) {
                    Text("Choose Picture…")
                }
                .fileImporter(
                    isPresented: $isImportingAvatarAccountForm,
                    allowedContentTypes: [.png, .jpeg, .webP, .gif],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            submitAvatarAccountForm(fileURL: url)
                        }
                    case .failure(let error):
                        logger.error("[fileImporter] Error: \(error)")
                    }
                }

                if (self.signedInUser?.avatarUrl != nil) {
                    Button(action: removeAvatarAccountForm) {
                        Text("Remove Picture")
                    }
                }
            }
            .font(.system(size: 11))
            .disabled(self.avatarSendingAccountForm)

            if !self.avatarPresetsAccountForm.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 52), spacing: 8)], spacing: 8) {
                    ForEach(self.avatarPresetsAccountForm) { preset in
                        Button(action: { submitAvatarPresetAccountForm(preset: preset) }) {
                            AsyncImage(url: URL(string: preset.url)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Circle()
                                    .fill(.secondary.opacity(0.2))
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            // the preset being set
                            .overlay {
                                if self.avatarPresetSendingAccountForm == preset.name {
                                    Circle()
                                        .stroke(Color.accentColor, lineWidth: 3)
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                }
                .frame(maxWidth: 340)
                .disabled(self.avatarSendingAccountForm)
            }
        }
        .padding(.vertical, 6)
    }

    // My Account: the account's plan and what it uses of it (GET /account),
    // read again each time the page opens
    var accountUsage: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let plan = planUsage {
                Text("Account usage")
                    .font(.system(size: 13, weight: .semibold))
                if !plan.hasPlan {
                    Text("No plan: your site is offline and takes no new files.")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
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
        }
        .frame(width: 260)
        .padding(10)
        .task {
            planUsage = await PlanUsage.fetch()
        }
    }
}

