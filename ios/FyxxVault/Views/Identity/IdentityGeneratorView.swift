import SwiftUI

// MARK: - Identity Generator

struct IdentityGeneratorView: View {
    @State private var identity: GeneratedIdentity = IdentityGenerator.generate(country: "France")
    @State private var selectedCountry = "France"
    @State private var showCard = false
    @State private var isFlipped = false
    @State private var copiedField: String?

    let countries = ["France", "USA", "UK", "Allemagne", "Espagne", "Italie", "Belgique", "Canada", "Suisse", "Japon", "Brésil"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Country picker
                    countryPicker

                    // Virtual card
                    virtualCard

                    // Identity fields
                    identityFields

                    // Regenerate button
                    FVButton(title: "Régénérer", icon: "arrow.clockwise") {
                        fvHaptic(.medium)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            identity = IdentityGenerator.generate(country: selectedCountry)
                            isFlipped = false
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(FVAnimatedBackground())
            .navigationTitle("Identité fictive")
            .fvInlineNavTitle()
        }
    }

    // MARK: - Country Picker

    private var countryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAYS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(FVColor.smoke)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(countries, id: \.self) { country in
                        Button {
                            selectedCountry = country
                            identity = IdentityGenerator.generate(country: country)
                            isFlipped = false
                        } label: {
                            Text(country)
                                .font(FVFont.caption(12))
                                .foregroundStyle(selectedCountry == country ? FVColor.abyss : FVColor.silver)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedCountry == country ? FVColor.cyan : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Virtual Card (3D flip)

    private var virtualCard: some View {
        ZStack {
            if !isFlipped {
                cardFront
                    .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
            } else {
                cardBack
                    .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
            }
        }
        .frame(height: 200)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
        .overlay(
            VStack {
                Spacer()
                Text("Appuyez pour retourner")
                    .font(FVFont.caption(11))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 4)
            }
        )
    }

    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: identity.cardType == "visa"
                            ? [Color(red: 0.1, green: 0.2, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 0.9)]
                            : [Color(red: 0.8, green: 0.2, blue: 0.1), Color(red: 0.95, green: 0.6, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            // Noise pattern
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.03))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(identity.cardType == "visa" ? "VISA" : "MASTERCARD")
                        .font(.system(size: 22, weight: .black, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                        .italic(identity.cardType == "visa")
                    Spacer()
                    Image(systemName: "wifi")
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 22))
                }

                Spacer()

                // Chip
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(colors: [Color(red: 0.9, green: 0.8, blue: 0.5), Color(red: 0.7, green: 0.6, blue: 0.3)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 44, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))

                Spacer()

                Text(formatCardNumber(identity.cardNumber))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .tracking(2)

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("EXPIRE").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                        Text(identity.cardExpiry).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text(identity.cardHolder.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            .padding(20)
        }
    }

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: identity.cardType == "visa"
                            ? [Color(red: 0.1, green: 0.2, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 0.9)]
                            : [Color(red: 0.8, green: 0.2, blue: 0.1), Color(red: 0.95, green: 0.6, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)

            VStack(spacing: 0) {
                // Magnetic strip
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 44)

                Spacer()

                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .frame(height: 36)
                    Text(identity.cardCVV)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Color.white)
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func formatCardNumber(_ number: String) -> String {
        var result = ""
        for (i, c) in number.enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(c)
        }
        return result
    }

    // MARK: - Identity Fields

    private var identityFields: some View {
        VStack(spacing: 12) {
            // Personal info
            sectionCard("Identité personnelle", icon: "person.fill", color: FVColor.violet) {
                fieldRow("Prénom", value: identity.firstName, field: "firstName")
                Divider().background(FVColor.cardBorder)
                fieldRow("Nom", value: identity.lastName, field: "lastName")
                Divider().background(FVColor.cardBorder)
                fieldRow("Genre", value: identity.gender, field: "gender")
                Divider().background(FVColor.cardBorder)
                fieldRow("Date de naissance", value: identity.birthDate, field: "birthDate")
            }

            // Contact
            sectionCard("Contact", icon: "phone.fill", color: FVColor.cyan) {
                fieldRow("Email", value: identity.email, field: "email")
                Divider().background(FVColor.cardBorder)
                fieldRow("Téléphone", value: identity.phone, field: "phone")
            }

            // Address
            sectionCard("Adresse", icon: "map.fill", color: FVColor.success) {
                fieldRow("Rue", value: identity.address, field: "address")
                Divider().background(FVColor.cardBorder)
                fieldRow("Ville", value: identity.city, field: "city")
                Divider().background(FVColor.cardBorder)
                fieldRow("Code postal", value: identity.zip, field: "zip")
                Divider().background(FVColor.cardBorder)
                fieldRow("Pays", value: identity.country, field: "country")
            }

            // Card info
            sectionCard("Carte bancaire", icon: "creditcard.fill", color: FVColor.gold) {
                fieldRow("Numéro", value: formatCardNumber(identity.cardNumber), field: "cardNumber")
                Divider().background(FVColor.cardBorder)
                fieldRow("Titulaire", value: identity.cardHolder, field: "cardHolder")
                Divider().background(FVColor.cardBorder)
                fieldRow("Expiration", value: identity.cardExpiry, field: "cardExpiry")
                Divider().background(FVColor.cardBorder)
                fieldRow("CVV", value: identity.cardCVV, field: "cardCVV")
            }
        }
    }

    private func sectionCard<Content: View>(_ title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(FVColor.smoke)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(FVColor.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FVColor.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func fieldRow(_ label: String, value: String, field: String) -> some View {
        HStack {
            Text(label)
                .font(FVFont.caption(13))
                .foregroundStyle(FVColor.smoke)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(FVFont.body(13))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button {
                ClipboardService.copy(value)
                copiedField = field
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if copiedField == field { copiedField = nil }
                }
            } label: {
                Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(copiedField == field ? FVColor.success : FVColor.cyan)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Identity Generator Engine

enum IdentityGenerator {
    static func generate(country: String) -> GeneratedIdentity {
        let db = countryData[country] ?? countryData["France"]!
        let isMale = Bool.random()
        let firstName = isMale ? db.maleFirstNames.randomElement()! : db.femaleFirstNames.randomElement()!
        let lastName = db.lastNames.randomElement()!
        let gender = isMale ? "Masculin" : "Féminin"
        let email = makeEmail(firstName: firstName, lastName: lastName)
        let phone = makePhone(db: db)
        let address = "\(Int.random(in: 1...150)) \(db.streets.randomElement()!)"
        let city = db.cities.randomElement()!
        let zip = makeZip(db: db)
        let birthYear = Int.random(in: 1960...2000)
        let birthMonth = Int.random(in: 1...12)
        let birthDay = Int.random(in: 1...28)
        let birthDate = String(format: "%02d/%02d/%04d", birthDay, birthMonth, birthYear)
        let (cardNumber, cardType) = makeCard()
        let expiryYear = Int.random(in: 27...32)
        let expiryMonth = Int.random(in: 1...12)
        let expiry = String(format: "%02d/%02d", expiryMonth, expiryYear)
        let cvv = String(format: "%03d", Int.random(in: 0...999))

        return GeneratedIdentity(
            firstName: firstName, lastName: lastName,
            email: email, phone: phone,
            address: address, city: city, zip: zip, country: country,
            birthDate: birthDate, gender: gender,
            cardNumber: cardNumber, cardHolder: "\(firstName) \(lastName)",
            cardExpiry: expiry, cardCVV: cvv, cardType: cardType
        )
    }

    private static func makeEmail(firstName: String, lastName: String) -> String {
        let domains = ["gmail.com", "outlook.com", "yahoo.fr", "hotmail.fr", "protonmail.com"]
        let num = Bool.random() ? "\(Int.random(in: 1...99))" : ""
        let formats = [
            "\(firstName.lowercased()).\(lastName.lowercased())\(num)",
            "\(firstName.lowercased())\(num)",
            "\(String(firstName.prefix(1)).lowercased())\(lastName.lowercased())\(num)"
        ]
        return "\(formats.randomElement()!)@\(domains.randomElement()!)"
    }

    private static func makePhone(db: CountryData) -> String {
        let digits = (0..<db.phoneDigits).map { _ in Int.random(in: 0...9) }.map(String.init).joined()
        return db.phonePrefix + digits
    }

    private static func makeZip(db: CountryData) -> String {
        String(format: db.zipFormat, Int.random(in: db.zipRange))
    }

    private static func makeCard() -> (String, String) {
        let isVisa = Bool.random()
        var digits: [Int]
        if isVisa {
            digits = [4] + (0..<14).map { _ in Int.random(in: 0...9) }
        } else {
            let prefix = [51, 52, 53, 54, 55].randomElement()!
            digits = [prefix / 10, prefix % 10] + (0..<13).map { _ in Int.random(in: 0...9) }
        }
        // Luhn check digit
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 0 {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        let checkDigit = (10 - (sum % 10)) % 10
        digits.append(checkDigit)
        return (digits.map(String.init).joined(), isVisa ? "visa" : "mastercard")
    }

    // MARK: - Country Data

    struct CountryData {
        var maleFirstNames: [String]
        var femaleFirstNames: [String]
        var lastNames: [String]
        var cities: [String]
        var streets: [String]
        var phonePrefix: String
        var phoneDigits: Int
        var zipFormat: String
        var zipRange: ClosedRange<Int>
    }

    static let countryData: [String: CountryData] = [
        "France": CountryData(
            maleFirstNames: ["Thomas", "Nicolas", "Julien", "Alexandre", "Antoine", "Maxime", "Pierre", "François", "Lucas", "Hugo"],
            femaleFirstNames: ["Sophie", "Marie", "Camille", "Léa", "Emma", "Chloé", "Manon", "Océane", "Laura", "Charlotte"],
            lastNames: ["Martin", "Bernard", "Dubois", "Thomas", "Robert", "Richard", "Petit", "Durand", "Leroy", "Moreau", "Simon", "Laurent"],
            cities: ["Paris", "Lyon", "Marseille", "Toulouse", "Bordeaux", "Nantes", "Strasbourg", "Montpellier", "Rennes", "Grenoble"],
            streets: ["rue de la Paix", "avenue Victor Hugo", "boulevard Haussmann", "rue du Faubourg Saint-Antoine", "avenue des Champs-Élysées"],
            phonePrefix: "+33 6 ", phoneDigits: 8,
            zipFormat: "%05d", zipRange: 1000...95999
        ),
        "USA": CountryData(
            maleFirstNames: ["James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph", "Thomas", "Charles"],
            femaleFirstNames: ["Mary", "Patricia", "Jennifer", "Linda", "Barbara", "Elizabeth", "Susan", "Jessica", "Sarah", "Karen"],
            lastNames: ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Wilson", "Martinez"],
            cities: ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose"],
            streets: ["Main St", "Oak Ave", "Maple Dr", "Cedar Blvd", "Elm St", "Washington Ave", "Park Rd", "Lake Dr"],
            phonePrefix: "+1 ", phoneDigits: 10,
            zipFormat: "%05d", zipRange: 10000...99999
        ),
        "UK": CountryData(
            maleFirstNames: ["Oliver", "Harry", "Jack", "George", "Noah", "Charlie", "James", "William", "Thomas", "Henry"],
            femaleFirstNames: ["Olivia", "Emily", "Isla", "Amelia", "Ava", "Lily", "Sophie", "Mia", "Isabella", "Ella"],
            lastNames: ["Smith", "Jones", "Williams", "Taylor", "Brown", "Davies", "Evans", "Wilson", "Thomas", "Johnson"],
            cities: ["London", "Birmingham", "Manchester", "Glasgow", "Liverpool", "Edinburgh", "Bristol", "Sheffield", "Leeds", "Cardiff"],
            streets: ["High Street", "Church Lane", "Victoria Road", "Manor Way", "Park Avenue", "King Street", "Queen Street"],
            phonePrefix: "+44 7", phoneDigits: 9,
            zipFormat: "SW%d 1AB", zipRange: 1...9
        ),
        "Allemagne": CountryData(
            maleFirstNames: ["Hans", "Klaus", "Wolfgang", "Stefan", "Michael", "Thomas", "Andreas", "Christian", "Daniel", "Markus"],
            femaleFirstNames: ["Anna", "Maria", "Petra", "Sabine", "Claudia", "Monika", "Katharina", "Jessica", "Laura", "Julia"],
            lastNames: ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann"],
            cities: ["Berlin", "Hamburg", "München", "Köln", "Frankfurt", "Stuttgart", "Düsseldorf", "Leipzig", "Dortmund", "Essen"],
            streets: ["Hauptstraße", "Schulstraße", "Gartenstraße", "Bahnhofstraße", "Kirchstraße", "Bergstraße"],
            phonePrefix: "+49 1", phoneDigits: 10,
            zipFormat: "%05d", zipRange: 10000...99999
        ),
        "Espagne": CountryData(
            maleFirstNames: ["José", "Antonio", "Manuel", "David", "Juan", "Francisco", "Javier", "Daniel", "Carlos", "Miguel"],
            femaleFirstNames: ["María", "Carmen", "Ana", "Laura", "Isabel", "Elena", "Sofía", "Paula", "Sara", "Marta"],
            lastNames: ["García", "González", "Rodríguez", "Fernández", "López", "Martínez", "Sánchez", "Pérez", "Gómez", "Martín"],
            cities: ["Madrid", "Barcelona", "Valencia", "Sevilla", "Zaragoza", "Málaga", "Murcia", "Palma", "Bilbao", "Alicante"],
            streets: ["Calle Mayor", "Avenida de la Paz", "Calle del Sol", "Plaza España", "Calle Real"],
            phonePrefix: "+34 6", phoneDigits: 8,
            zipFormat: "%05d", zipRange: 1000...52999
        ),
        "Italie": CountryData(
            maleFirstNames: ["Marco", "Luca", "Alessandro", "Matteo", "Lorenzo", "Andrea", "Giovanni", "Francesco", "Antonio", "Davide"],
            femaleFirstNames: ["Sofia", "Giulia", "Martina", "Sara", "Valentina", "Federica", "Chiara", "Alice", "Elena", "Laura"],
            lastNames: ["Rossi", "Ferrari", "Esposito", "Bianchi", "Romano", "Colombo", "Ricci", "Marino", "Greco", "Bruno"],
            cities: ["Roma", "Milano", "Napoli", "Torino", "Palermo", "Genova", "Bologna", "Firenze", "Bari", "Catania"],
            streets: ["Via Roma", "Via Nazionale", "Corso Italia", "Via Garibaldi", "Via Mazzini"],
            phonePrefix: "+39 3", phoneDigits: 9,
            zipFormat: "%05d", zipRange: 10000...98999
        ),
        "Belgique": CountryData(
            maleFirstNames: ["Liam", "Noah", "Lucas", "Arthur", "Hugo", "Nathan", "Thomas", "Mathieu", "Louis", "Remi"],
            femaleFirstNames: ["Emma", "Mia", "Olivia", "Sofia", "Alice", "Lea", "Manon", "Clara", "Juliette", "Louise"],
            lastNames: ["Dupont", "Dubois", "Lambert", "Martin", "Simon", "Laurent", "Lecomte", "Maes", "Claes", "Jacobs"],
            cities: ["Bruxelles", "Anvers", "Gand", "Charleroi", "Liège", "Bruges", "Namur", "Leuven", "Mons", "Hasselt"],
            streets: ["Rue de la Loi", "Avenue Louise", "Chaussée de Louvain", "Rue Neuve", "Boulevard du Roi Albert"],
            phonePrefix: "+32 4", phoneDigits: 8,
            zipFormat: "%04d", zipRange: 1000...9999
        ),
        "Canada": CountryData(
            maleFirstNames: ["Liam", "Noah", "William", "Oliver", "Lucas", "Ethan", "Mason", "Logan", "Jackson", "Jacob"],
            femaleFirstNames: ["Emma", "Olivia", "Ava", "Isabella", "Sophia", "Mia", "Charlotte", "Amelia", "Harper", "Evelyn"],
            lastNames: ["Smith", "Brown", "Tremblay", "Martin", "Roy", "Wilson", "MacDonald", "Taylor", "Johnson", "Anderson"],
            cities: ["Toronto", "Montreal", "Vancouver", "Calgary", "Ottawa", "Edmonton", "Mississauga", "Winnipeg", "Quebec City", "Hamilton"],
            streets: ["Main Street", "King Street", "Queen Street", "Park Avenue", "Maple Drive"],
            phonePrefix: "+1 6", phoneDigits: 9,
            zipFormat: "M%dA 1A1", zipRange: 1...9
        ),
        "Suisse": CountryData(
            maleFirstNames: ["Luca", "Noah", "Jonas", "David", "Nico", "Tim", "Jan", "Marco", "Simon", "Fabian"],
            femaleFirstNames: ["Emma", "Lena", "Anna", "Laura", "Leonie", "Julia", "Sophie", "Nina", "Lisa", "Sara"],
            lastNames: ["Müller", "Meier", "Schmid", "Keller", "Weber", "Huber", "Meyer", "Schneider", "Fischer", "Gerber"],
            cities: ["Zürich", "Genève", "Basel", "Bern", "Lausanne", "Winterthur", "St. Gallen", "Luzern", "Biel", "Thun"],
            streets: ["Hauptstrasse", "Bahnhofstrasse", "Dorfstrasse", "Schulstrasse", "Bergstrasse"],
            phonePrefix: "+41 7", phoneDigits: 8,
            zipFormat: "%04d", zipRange: 1000...9999
        ),
        "Japon": CountryData(
            maleFirstNames: ["Haruto", "Yuki", "Sota", "Hayato", "Haruki", "Ryota", "Takumi", "Yuto", "Kaito", "Sho"],
            femaleFirstNames: ["Hina", "Yui", "Mio", "Riko", "Sakura", "Aoi", "Rin", "Nana", "Mei", "Koharu"],
            lastNames: ["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Hayashi", "Kobayashi"],
            cities: ["Tokyo", "Osaka", "Yokohama", "Nagoya", "Sapporo", "Fukuoka", "Kobe", "Kyoto", "Kawasaki", "Saitama"],
            streets: ["Ginza Street", "Shibuya Avenue", "Shinjuku Road", "Harajuku Lane", "Roppongi Boulevard"],
            phonePrefix: "+81 9", phoneDigits: 9,
            zipFormat: "%03d-%04d", zipRange: 100...999
        ),
        "Brésil": CountryData(
            maleFirstNames: ["Miguel", "Arthur", "Davi", "Gabriel", "Lucas", "Mateus", "Bernardo", "Heitor", "Samuel", "Enzo"],
            femaleFirstNames: ["Sofia", "Alice", "Laura", "Isabella", "Manuela", "Giulia", "Valentina", "Beatriz", "Helena", "Lara"],
            lastNames: ["Silva", "Santos", "Oliveira", "Souza", "Rodrigues", "Ferreira", "Alves", "Pereira", "Lima", "Gomes"],
            cities: ["São Paulo", "Rio de Janeiro", "Brasília", "Salvador", "Fortaleza", "Belo Horizonte", "Manaus", "Curitiba", "Recife", "Porto Alegre"],
            streets: ["Avenida Paulista", "Rua das Flores", "Avenida Brasil", "Rua da Liberdade", "Avenida Central"],
            phonePrefix: "+55 1", phoneDigits: 10,
            zipFormat: "%05d-%03d", zipRange: 10000...99999
        )
    ]
}
