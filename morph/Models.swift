import Foundation
import SwiftUI

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    var id: String = UUID().uuidString
    var email: String = ""
    var name: String = ""
    var age: Int = 25
    var gender: Gender = .preferNotToSay
    var heightCm: Double = 175
    var weightKg: Double = 75
    var goalWeightKg: Double = 70
    var fitnessGoal: FitnessGoal = .buildMuscle
    var activityLevel: ActivityLevel = .moderate
    var hasCompletedOnboarding: Bool = false
    var lastResetDate: Date = Date()

    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case preferNotToSay = "Prefer not to say"
    }

    enum FitnessGoal: String, Codable, CaseIterable {
        case buildMuscle = "Build Muscle"
        case loseFat = "Lose Body Fat"
        case recomposition = "Recomposition"
        case maintain = "Maintain"
        case improveAthletics = "Improve Athletics"

        var icon: String {
            switch self {
            case .buildMuscle: return "figure.strengthtraining.traditional"
            case .loseFat: return "flame.fill"
            case .recomposition: return "arrow.triangle.2.circlepath"
            case .maintain: return "checkmark.shield.fill"
            case .improveAthletics: return "bolt.fill"
            }
        }
    }

    enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary = "Sedentary"
        case light = "Lightly Active"
        case moderate = "Moderately Active"
        case active = "Very Active"
        case extreme = "Extremely Active"

        var description: String {
            switch self {
            case .sedentary: return "Little or no exercise"
            case .light: return "1–3 days/week"
            case .moderate: return "3–5 days/week"
            case .active: return "6–7 days/week"
            case .extreme: return "2x/day or physical job"
            }
        }
    }

}

// MARK: - Physique Check-In
struct PhysiqueCheckIn: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: Date = Date()
    var weightKg: Double
    var photoFront: Data?
    var photoBack: Data?
    var photoLeft: Data?
    var photoRight: Data?
    var notes: String = ""
    var analysis: PhysiqueAnalysis?
    var isAnalyzing: Bool = false

    var photoCount: Int {
        [photoFront, photoBack, photoLeft, photoRight].compactMap { $0 }.count
    }

    var isComplete: Bool { photoCount == 4 }

    func photo(for direction: PhotoDirection) -> Data? {
        switch direction {
        case .front: return photoFront
        case .back:  return photoBack
        case .left:  return photoLeft
        case .right: return photoRight
        }
    }
}

// MARK: - AI Analysis Result
struct PhysiqueAnalysis: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: Date = Date()

    // Scores out of 10
    var overallScore: Double
    var symmetryScore: Double
    var muscularDevelopmentScore: Double
    var bodyFatScore: Double
    var proportionScore: Double
    var progressScore: Double?

    // Estimated metrics
    var estimatedBodyFatPercent: Double?
    var estimatedMuscleRating: String

    // Detailed feedback
    var strengthAreas: [String]
    var improvementAreas: [String]
    var weeklyFocus: String

    // Nutrition targets (calculated from user profile + visual assessment)
    var dailyCalorieTarget: Int
    var proteinGrams: Int
    var carbGrams: Int
    var fatGrams: Int
    var mealTimingTips: [String]

    // Training
    var suggestedTrainingSplit: String
    var weeklyTrainingBreakdown: [String]
    var dietRecommendations: [String]
    var trainingRecommendations: [String]
    var supplementSuggestions: [String]

    // Summary
    var coachSummary: String

    var formattedBodyFat: String {
        guard let bf = estimatedBodyFatPercent else { return "—" }
        return String(format: "~%.0f%%", bf)
    }

    init(
        overallScore: Double, symmetryScore: Double, muscularDevelopmentScore: Double,
        bodyFatScore: Double, proportionScore: Double, progressScore: Double?,
        estimatedBodyFatPercent: Double?, estimatedMuscleRating: String,
        strengthAreas: [String], improvementAreas: [String], weeklyFocus: String,
        dailyCalorieTarget: Int, proteinGrams: Int, carbGrams: Int, fatGrams: Int,
        mealTimingTips: [String], suggestedTrainingSplit: String, weeklyTrainingBreakdown: [String],
        dietRecommendations: [String], trainingRecommendations: [String],
        supplementSuggestions: [String], coachSummary: String
    ) {
        self.overallScore = overallScore
        self.symmetryScore = symmetryScore
        self.muscularDevelopmentScore = muscularDevelopmentScore
        self.bodyFatScore = bodyFatScore
        self.proportionScore = proportionScore
        self.progressScore = progressScore
        self.estimatedBodyFatPercent = estimatedBodyFatPercent
        self.estimatedMuscleRating = estimatedMuscleRating
        self.strengthAreas = strengthAreas
        self.improvementAreas = improvementAreas
        self.weeklyFocus = weeklyFocus
        self.dailyCalorieTarget = dailyCalorieTarget
        self.proteinGrams = proteinGrams
        self.carbGrams = carbGrams
        self.fatGrams = fatGrams
        self.mealTimingTips = mealTimingTips
        self.suggestedTrainingSplit = suggestedTrainingSplit
        self.weeklyTrainingBreakdown = weeklyTrainingBreakdown
        self.dietRecommendations = dietRecommendations
        self.trainingRecommendations = trainingRecommendations
        self.supplementSuggestions = supplementSuggestions
        self.coachSummary = coachSummary
    }

    // Tolerant decoding: missing fields fall back to defaults instead of
    // failing the whole decode and wiping saved check-in history.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                       = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date                     = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        overallScore             = try c.decodeIfPresent(Double.self, forKey: .overallScore) ?? 5
        symmetryScore            = try c.decodeIfPresent(Double.self, forKey: .symmetryScore) ?? 5
        muscularDevelopmentScore = try c.decodeIfPresent(Double.self, forKey: .muscularDevelopmentScore) ?? 5
        bodyFatScore             = try c.decodeIfPresent(Double.self, forKey: .bodyFatScore) ?? 5
        proportionScore          = try c.decodeIfPresent(Double.self, forKey: .proportionScore) ?? 5
        progressScore            = try c.decodeIfPresent(Double.self, forKey: .progressScore)
        estimatedBodyFatPercent  = try c.decodeIfPresent(Double.self, forKey: .estimatedBodyFatPercent)
        estimatedMuscleRating    = try c.decodeIfPresent(String.self, forKey: .estimatedMuscleRating) ?? "average"
        strengthAreas            = try c.decodeIfPresent([String].self, forKey: .strengthAreas) ?? []
        improvementAreas         = try c.decodeIfPresent([String].self, forKey: .improvementAreas) ?? []
        weeklyFocus              = try c.decodeIfPresent(String.self, forKey: .weeklyFocus) ?? ""
        dailyCalorieTarget       = try c.decodeIfPresent(Int.self, forKey: .dailyCalorieTarget) ?? 2000
        proteinGrams             = try c.decodeIfPresent(Int.self, forKey: .proteinGrams) ?? 150
        carbGrams                = try c.decodeIfPresent(Int.self, forKey: .carbGrams) ?? 200
        fatGrams                 = try c.decodeIfPresent(Int.self, forKey: .fatGrams) ?? 65
        mealTimingTips           = try c.decodeIfPresent([String].self, forKey: .mealTimingTips) ?? []
        suggestedTrainingSplit   = try c.decodeIfPresent(String.self, forKey: .suggestedTrainingSplit) ?? ""
        weeklyTrainingBreakdown  = try c.decodeIfPresent([String].self, forKey: .weeklyTrainingBreakdown) ?? []
        dietRecommendations      = try c.decodeIfPresent([String].self, forKey: .dietRecommendations) ?? []
        trainingRecommendations  = try c.decodeIfPresent([String].self, forKey: .trainingRecommendations) ?? []
        supplementSuggestions    = try c.decodeIfPresent([String].self, forKey: .supplementSuggestions) ?? []
        coachSummary             = try c.decodeIfPresent(String.self, forKey: .coachSummary) ?? ""
    }
}

// MARK: - Photo Direction
enum PhotoDirection: String, CaseIterable, Identifiable {
    case front = "Front"
    case back = "Back"
    case left = "Left Side"
    case right = "Right Side"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .front: return "person.fill"
        case .back: return "arrow.uturn.backward"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var instruction: String {
        switch self {
        case .front: return "Face the camera, arms relaxed at sides"
        case .back: return "Turn away from camera, arms relaxed"
        case .left: return "Left side profile, arms forward"
        case .right: return "Right side profile, arms forward"
        }
    }
}
