//
//  CustomizationScreenView.swift
//  MileageTax — 3-Step Driver Setup Wizard
//

import SwiftUI

private struct CountryPreset: Identifiable {
    let id = UUID()
    let flag: String
    let name: String
    let rate: Double
    let currency: String
    let unit: String
    let label: String
}

private let countryPresets: [CountryPreset] = [
    CountryPreset(flag: "🇺🇸", name: "United States",    rate: 0.670, currency: "$",  unit: "mi", label: "IRS Standard (USA)"),
    CountryPreset(flag: "🇬🇧", name: "United Kingdom",   rate: 0.450, currency: "£",  unit: "mi", label: "HMRC Rate (UK)"),
    CountryPreset(flag: "🇨🇦", name: "Canada",           rate: 0.680, currency: "CA$",unit: "km", label: "CRA Rate (Canada)"),
    CountryPreset(flag: "🇦🇺", name: "Australia",        rate: 0.850, currency: "A$", unit: "km", label: "ATO Rate (Australia)"),
    CountryPreset(flag: "🇩🇪", name: "Germany",          rate: 0.300, currency: "€",  unit: "km", label: "Bundesamt (Germany)"),
    CountryPreset(flag: "🇫🇷", name: "France",           rate: 0.286, currency: "€",  unit: "km", label: "Fisc Rate (France)"),
    CountryPreset(flag: "🇮🇳", name: "India",            rate: 0.140, currency: "₹",  unit: "km", label: "IT Rate (India)"),
    CountryPreset(flag: "🇯🇵", name: "Japan",            rate: 0.150, currency: "¥",  unit: "km", label: "NTA Rate (Japan)"),
    CountryPreset(flag: "🇸🇬", name: "Singapore",        rate: 0.450, currency: "S$", unit: "km", label: "IRAS Rate (Singapore)"),
    CountryPreset(flag: "🇳🇿", name: "New Zealand",      rate: 0.830, currency: "NZ$",unit: "km", label: "IRD Rate (NZ)"),
    CountryPreset(flag: "🇿🇦", name: "South Africa",     rate: 0.460, currency: "R",  unit: "km", label: "SARS Rate (SA)"),
    CountryPreset(flag: "🇧🇷", name: "Brazil",           rate: 0.220, currency: "R$", unit: "km", label: "Receita Federal"),
    CountryPreset(flag: "🇲🇽", name: "Mexico",           rate: 0.240, currency: "MX$",unit: "km", label: "SAT Rate (Mexico)"),
    CountryPreset(flag: "🇳🇱", name: "Netherlands",      rate: 0.230, currency: "€",  unit: "km", label: "Belastingdienst"),
    CountryPreset(flag: "🇸🇪", name: "Sweden",           rate: 0.185, currency: "kr", unit: "km", label: "Skatteverket"),
    CountryPreset(flag: "🇨🇭", name: "Switzerland",      rate: 0.700, currency: "CHF",unit: "km", label: "ESTV Rate"),
    CountryPreset(flag: "🇦🇪", name: "UAE",              rate: 0.340, currency: "AED",unit: "km", label: "FTA Rate (UAE)"),
    CountryPreset(flag: "🇸🇦", name: "Saudi Arabia",     rate: 0.310, currency: "SAR",unit: "km", label: "GAZT Rate"),
    CountryPreset(flag: "🇰🇷", name: "South Korea",      rate: 0.200, currency: "₩",  unit: "km", label: "NTS Rate"),
    CountryPreset(flag: "🇪🇸", name: "Spain",            rate: 0.190, currency: "€",  unit: "km", label: "AEAT Rate"),
]

private enum VehicleType: String, CaseIterable {
    case car = "Car"
    case ev = "EV"
    case motorcycle = "Motorcycle"
    case truck = "Truck"

    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .ev: return "bolt.car.fill"
        case .motorcycle: return "bicycle"
        case .truck: return "truck.box.fill"
        }
    }
    var rateMultiplier: Double {
        switch self {
        case .car, .truck: return 1.0
        case .ev: return 0.9
        case .motorcycle: return 0.8
        }
    }
}

struct CustomizationScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @AppStorage(AppStorageKeys.hasSeenCustomization)  private var hasSeenCustomization = false
    @AppStorage(AppStorageKeys.irsRateOverride)       private var irsRate: Double       = MileageTaxDefaults.irsRatePerMile
    @AppStorage(AppStorageKeys.currencySymbol)        private var currencySymbol: String = MileageTaxDefaults.defaultCurrencySymbol
    @AppStorage(AppStorageKeys.distanceUnit)          private var distanceUnit: String   = MileageTaxDefaults.defaultDistanceUnit
    @AppStorage(AppStorageKeys.countryTaxLabel)       private var countryTaxLabel: String = MileageTaxDefaults.defaultCountryLabel
    @AppStorage(AppStorageKeys.weeklyReportEnabled)   private var weeklyReport = true
    @AppStorage(AppStorageKeys.autoClassifyWorkHours) private var autoWorkHours = true

    @AppStorage(AppStorageKeys.userName) private var userName: String = ""
    @State private var profilePhotoData: Data? = UserDefaults.standard.data(forKey: "MT_userPhotoData")
    @State private var showPhotoPicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var step = 0
    @State private var searchText = ""
    @State private var selectedCountry: CountryPreset? = countryPresets.first
    @State private var selectedVehicle: VehicleType = .car
    @State private var stepOpacity: Double = 1
    @State private var stepOffset: CGFloat = 0
    @State private var carOffset: CGFloat = 0
    @State private var customRate: Double = 0.67
    @State private var useCustomRate = false

    private var filteredCountries: [CountryPreset] {
        searchText.isEmpty ? countryPresets : countryPresets.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.flag.contains(searchText)
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "#06090E").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerBar

                // Step indicator
                stepIndicator

                // Content
                ZStack {
                    if step == 0 { step0ProfileSetup }
                    if step == 1 { step1CountryPicker }
                    if step == 2 { step3Preferences }
                }
                .opacity(stepOpacity)
                .offset(y: stepOffset)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: step)

                Spacer()

                // Bottom CTA
                bottomCTA
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(["Who Are You?", "Your Location & Tax Rate", "Driving Preferences"][step])
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Step \(step + 1) of 3")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            Button { hasSeenCustomization = true } label: {
                Text("Skip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .opacity(step == 2 ? 0 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 12)
    }

    // MARK: - Step Indicator
    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= step ? Color(hex: "#00FF88") : Color.white.opacity(0.12))
                    .frame(height: 4)
                    .animation(.spring(response: 0.4), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Step 0: Profile Setup

    private var step0ProfileSetup: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Photo picker circle
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
                                        colors: [Color(hex: "#00E5FF").opacity(0.6), Color(hex: "#00FF88").opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 2.5
                                )
                            )
                            .shadow(color: Color(hex: "#00E5FF").opacity(0.2), radius: 16)

                        if let img = pickedImage ?? (profilePhotoData.flatMap { UIImage(data: $0) }) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 104, height: 104)
                                .clipShape(Circle())
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color(hex: "#00E5FF"))
                                Text("Add Photo")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        // Edit badge
                        Circle()
                            .fill(Color(hex: "#00FF88"))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "#041B12"))
                            )
                            .offset(x: 36, y: 36)
                    }
                }
                .sheet(isPresented: $showPhotoPicker) {
                    ImagePickerView { img in
                        pickedImage = img
                        if let d = img.jpegData(compressionQuality: 0.82) {
                            profilePhotoData = d
                            UserDefaults.standard.set(d, forKey: "MT_userPhotoData")
                        }
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR NAME")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(hex: "#00FF88").opacity(0.7))
                        .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#00E5FF"))

                        TextField("Enter your name...", text: $userName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .tint(Color(hex: "#00FF88"))
                            .submitLabel(.done)
                            .onChange(of: userName) { _, newVal in
                                if newVal.count > 10 {
                                    userName = String(newVal.prefix(10))
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#0E1622"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        userName.isEmpty ? Color.white.opacity(0.08) : Color(hex: "#00FF88").opacity(0.4),
                        lineWidth: 1.5
                    ))
                }
                .padding(.horizontal, 24)

                // Tagline card
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#00FF88"))
                    Text("Your name is stored only on this device — never shared.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color(hex: "#061A13").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#00FF88").opacity(0.15)))
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Step 1: Country Picker
    private var step1CountryPicker: some View {
        VStack(spacing: 14) {
            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search country...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "#00FF88"))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(hex: "#0E1622"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
            .padding(.horizontal, 24)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCountries) { country in
                        countryRow(country)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private func countryRow(_ country: CountryPreset) -> some View {
        let isSelected = selectedCountry?.id == country.id
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedCountry = country
                    irsRate = country.rate
                    currencySymbol = country.currency
                    distanceUnit = country.unit
                    customRate = country.rate
                    countryTaxLabel = country.label
                }
            } label: {
                HStack(spacing: 12) {
                    Text(country.flag)
                        .font(.system(size: 24))
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(country.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(country.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(String(format: "%@%.3f/%@", country.currency, country.rate, country.unit))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(isSelected ? Color(hex: "#00FF88") : .white.opacity(0.5))
                        .lineLimit(1)

                    ZStack {
                        Circle()
                            .strokeBorder(isSelected ? Color(hex: "#00FF88") : Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        if isSelected {
                            Circle().fill(Color(hex: "#00FF88")).frame(width: 10, height: 10)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isSelected {
                Rectangle()
                    .fill(Color(hex: "#00FF88").opacity(0.18))
                    .frame(height: 1)

                HStack(spacing: 10) {
                    // CURRENCY
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENCY")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        Menu {
                            ForEach(["$", "£", "€", "₹", "¥", "A$", "CA$", "S$", "CHF", "kr", "R", "R$", "AED", "₩"], id: \.self) { sym in
                                Button(sym) { currencySymbol = sym }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currencySymbol)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#00FF88"))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // UNIT
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UNIT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        Menu {
                            Button("mi") { distanceUnit = "mi" }
                            Button("km") { distanceUnit = "km" }
                        } label: {
                            HStack(spacing: 4) {
                                Text(distanceUnit)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(hex: "#00E5FF"))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // RATE
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("0.00", value: $customRate, format: .number)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 7)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onChange(of: customRate) { newVal in irsRate = newVal }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(hex: isSelected ? "#0D2218" : "#0A1018"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? Color(hex: "#00FF88").opacity(0.5) : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }

    // MARK: - Step 2: Distance & Currency
    private var step2DistanceCurrency: some View {
        VStack(spacing: 24) {
            // Animated car indicator
            VStack(spacing: 16) {
                Text("DISTANCE UNIT")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#0E1622"))
                        .frame(height: 64)

                    // Sliding pill background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#00FF88").opacity(0.15))
                        .padding(6)
                        .frame(width: UIScreen.main.bounds.width / 2 - 24)
                        .frame(maxWidth: .infinity, alignment: distanceUnit == "mi" ? .leading : .trailing)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: distanceUnit)

                    // Two options
                    HStack(spacing: 0) {
                        Button {
                            withAnimation { distanceUnit = "mi" }
                        } label: {
                            Text("Miles (mi)")
                                .font(.system(size: 15, weight: distanceUnit == "mi" ? .heavy : .medium))
                                .foregroundStyle(distanceUnit == "mi" ? Color(hex: "#00FF88") : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                        Button {
                            withAnimation { distanceUnit = "km" }
                        } label: {
                            Text("Kilometres (km)")
                                .font(.system(size: 15, weight: distanceUnit == "km" ? .heavy : .medium))
                                .foregroundStyle(distanceUnit == "km" ? Color(hex: "#00FF88") : .white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
            }

            // Currency picker
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENCY SYMBOL")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                let currencies = ["$", "£", "€", "₹", "¥", "A$", "CA$", "S$", "CHF", "kr", "R", "R$", "AED", "₩"]
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 10) {
                    ForEach(currencies, id: \.self) { sym in
                        Button {
                            withAnimation { currencySymbol = sym }
                        } label: {
                            Text(sym)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(currencySymbol == sym ? Color(hex: "#06090E") : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(currencySymbol == sym ? Color(hex: "#00FF88") : Color(hex: "#0E1622"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                                    currencySymbol == sym ? Color.clear : Color.white.opacity(0.07)))
                                .shadow(color: currencySymbol == sym ? Color(hex: "#00FF88").opacity(0.4) : .clear, radius: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Preferences
    private var step3Preferences: some View {
        VStack(spacing: 16) {
            // Vehicle type
            VStack(alignment: .leading, spacing: 12) {
                Text("VEHICLE TYPE")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                HStack(spacing: 10) {
                    ForEach(VehicleType.allCases, id: \.self) { v in
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedVehicle = v }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: v.icon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(selectedVehicle == v ? Color(hex: "#06090E") : Color(hex: "#00E5FF"))
                                Text(v.rawValue)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(selectedVehicle == v ? Color(hex: "#06090E") : .white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedVehicle == v ? Color(hex: "#00FF88") : Color(hex: "#0E1622"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                                selectedVehicle == v ? Color.clear : Color.white.opacity(0.07)))
                            .shadow(color: selectedVehicle == v ? Color(hex: "#00FF88").opacity(0.4) : .clear, radius: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Auto-classify toggle
            toggleCard(
                icon: "clock.badge.checkmark",
                title: "Work-Hours Auto-Classify",
                subtitle: "Business trips during 8AM–6PM auto-classified",
                isOn: $autoWorkHours
            )

            // Weekly report
            toggleCard(
                icon: "chart.bar.doc.horizontal",
                title: "Weekly Tax Summary",
                subtitle: "Every Sunday — your earnings and top routes",
                isOn: $weeklyReport
            )

            // Rate display
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#00FF88"))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "#0D2218"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tax Rate Configured")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(selectedCountry?.label ?? countryTaxLabel)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text(String(format: "%@%.3f", currencySymbol, selectedCountry?.rate ?? irsRate))
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: "#00FF88"))
            }
            .padding(14)
            .background(Color(hex: "#0A1018"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#00FF88").opacity(0.2)))
        }
        .padding(.horizontal, 24)
    }

    private func toggleCard(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "#00E5FF"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "#0C1F26"))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color(hex: "#00FF88"))
                .labelsHidden()
        }
        .padding(14)
        .background(Color(hex: "#0A1018"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07)))
    }

    // MARK: - Bottom CTA
    private var bottomCTA: some View {
        HStack(spacing: 14) {
            if step > 0 {
                Button {
                    withAnimation(.spring(response: 0.4)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "#0E1622"))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1)))
                }
            }

            Button {
                if step < 2 {
                    applyStepSettings()
                    withAnimation(.spring(response: 0.4)) { step += 1 }
                } else {
                    applyStepSettings()
                    ProfileStore.shared.save(name: userName, photo: profilePhotoData)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenCustomization = true
                        settings.hasSeenCustomization = true
                        settings.hasSeenNotificationPrompt = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(step == 2 ? "Start Tracking" : "Next")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Image(systemName: step == 2 ? "arrow.up.right" : "chevron.right")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(Color(hex: "#06090E"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [Color(hex: "#00E5FF"), Color(hex: "#00FF88")],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#00FF88").opacity(0.4), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 12)
        .background(
            LinearGradient(colors: [Color(hex: "#06090E").opacity(0), Color(hex: "#06090E")],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func applyStepSettings() {
        if let c = selectedCountry {
            let perMile = MileageUnits.perMileRate(from: c.rate, nativeUnit: c.unit)
            irsRate       = perMile * selectedVehicle.rateMultiplier
            currencySymbol = c.currency
            distanceUnit   = c.unit
            countryTaxLabel = c.label
        }
    }
}