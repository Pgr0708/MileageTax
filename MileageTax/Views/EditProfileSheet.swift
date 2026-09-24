//
//  EditProfileSheet.swift
//  MileageTax — Edit Profile Sheet (name + photo)
//

import SwiftUI
import UIKit

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.userName) private var userName: String = ""
    @Binding var profilePhotoData: Data?

    @State private var draftName: String = ""
    @State private var showPhotoPicker = false
    @State private var pickedImage: UIImage? = nil

    private var displayImage: UIImage? {
        pickedImage ?? profilePhotoData.flatMap { UIImage(data: $0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#06090E").ignoresSafeArea()

                RadialGradient(
                    colors: [Color(hex: "#00E5FF").opacity(0.07), .clear],
                    center: .top, startRadius: 0, endRadius: 280
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // Photo picker
                        Button { showPhotoPicker = true } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#102028"), Color(hex: "#0C121A")],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 110, height: 110)
                                    .overlay(
                                        Circle().strokeBorder(
                                            LinearGradient(
                                                colors: [Color(hex: "#00E5FF").opacity(0.6),
                                                         Color(hex: "#00FF88").opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ), lineWidth: 2.5
                                        )
                                    )
                                    .shadow(color: Color(hex: "#00E5FF").opacity(0.25), radius: 16)

                                if let img = displayImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 104, height: 104)
                                        .clipShape(Circle())
                                } else {
                                    VStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 26, weight: .bold))
                                            .foregroundStyle(Color(hex: "#00E5FF"))
                                        Text("Add Photo")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }

                                Circle()
                                    .fill(Color(hex: "#00FF88"))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color(hex: "#041B12"))
                                    )
                                    .offset(x: 36, y: 36)
                            }
                        }
                        .sheet(isPresented: $showPhotoPicker) {
                            ImagePickerView { img in pickedImage = img }
                        }

                        Text("Tap photo to change it")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .offset(y: -12)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("DISPLAY NAME")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#00FF88").opacity(0.7))
                                Spacer()
                                Text("\(draftName.count)/10")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(draftName.count >= 10
                                        ? Color(hex: "#FF4444").opacity(0.8)
                                        : Color.white.opacity(0.3))
                            }
                            .padding(.horizontal, 4)

                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#00E5FF"))

                                TextField("Your name...", text: $draftName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .tint(Color(hex: "#00FF88"))
                                    .submitLabel(.done)
                                    .onSubmit { saveAndDismiss() }
                                    .onChange(of: draftName) { _, newVal in
                                        if newVal.count > 10 {
                                            draftName = String(newVal.prefix(10))
                                        }
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#0E1622"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).strokeBorder(
                                    draftName.isEmpty
                                        ? Color.white.opacity(0.08)
                                        : Color(hex: "#00FF88").opacity(0.45),
                                    lineWidth: 1.5
                                )
                            )
                        }
                        .padding(.horizontal, 24)

                        // Privacy note
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#00FF88"))
                            Text("Name and photo are stored on-device only.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(14)
                        .background(Color(hex: "#061A13").opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#00FF88").opacity(0.15)))
                        .padding(.horizontal, 24)

                        // Save button
                        Button(action: saveAndDismiss) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Profile")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#041B12"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#00FF88"), Color(hex: "#00D670")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 12, y: 4)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 60)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#06090E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { draftName = userName }
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = trimmed
        if let img = pickedImage, let d = img.jpegData(compressionQuality: 0.82) {
            UserDefaults.standard.set(d, forKey: "MT_userPhotoData")
            profilePhotoData = d
        }
        ProfileStore.shared.save(name: trimmed, photo: profilePhotoData)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
