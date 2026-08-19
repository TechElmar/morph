import SwiftUI

/// Citations for every health figure the app produces, required by App Store
/// guideline 1.4.1. Reachable from the Profile tab and from the bottom of each
/// analysis, so it sits next to the numbers it explains.
struct SourcesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: MorphSpacing.lg) {
                        Text("Every number Morph shows you comes from a published method or an AI estimate. Here is exactly where each one comes from.")
                            .font(MorphFonts.body(15))
                            .foregroundColor(MorphColors.textSecondary)
                            .padding(.top, MorphSpacing.md)

                        SourceSection(
                            title: "Calorie Targets",
                            method: "Your baseline metabolic rate is calculated with the Mifflin-St Jeor equation, the equation the Academy of Nutrition and Dietetics recommends as the most accurate for healthy adults.",
                            citations: [
                                Citation(
                                    text: "Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO. A new predictive equation for resting energy expenditure in healthy individuals. American Journal of Clinical Nutrition. 1990;51(2):241-247.",
                                    url: "https://pubmed.ncbi.nlm.nih.gov/2305711/"
                                )
                            ]
                        )

                        SourceSection(
                            title: "Activity Multipliers",
                            method: "Your maintenance calories are your metabolic rate multiplied by an activity factor between 1.2 (sedentary) and 1.9 (extremely active), following standard physical activity level values.",
                            citations: [
                                Citation(
                                    text: "FAO/WHO/UNU. Human Energy Requirements: Report of a Joint Expert Consultation. 2004.",
                                    url: "https://www.fao.org/3/y5686e/y5686e00.htm"
                                )
                            ]
                        )

                        SourceSection(
                            title: "Cutting and Bulking Targets",
                            method: "Fat-loss targets apply a moderate daily calorie deficit and muscle-gain targets a moderate surplus, in the range generally recommended for gradual, sustainable change of roughly 0.25-0.5 kg per week.",
                            citations: [
                                Citation(
                                    text: "National Institute of Diabetes and Digestive and Kidney Diseases (NIH). Weight Management.",
                                    url: "https://www.niddk.nih.gov/health-information/weight-management"
                                )
                            ]
                        )

                        SourceSection(
                            title: "Protein and Macronutrients",
                            method: "Protein targets follow the range recommended for people doing regular resistance training, typically 1.4-2.0 grams per kilogram of body weight per day. Remaining calories are divided between carbohydrate and fat.",
                            citations: [
                                Citation(
                                    text: "Jager R, Kerksick CM, Campbell BI, et al. International Society of Sports Nutrition Position Stand: protein and exercise. Journal of the International Society of Sports Nutrition. 2017;14:20.",
                                    url: "https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8"
                                )
                            ]
                        )

                        SourceSection(
                            title: "Training Recommendations",
                            method: "Training splits and volume suggestions follow established guidance on resistance training frequency and weekly set volume for muscular development.",
                            citations: [
                                Citation(
                                    text: "Schoenfeld BJ, Ogborn D, Krieger JW. Effects of Resistance Training Frequency on Measures of Muscle Hypertrophy: A Systematic Review and Meta-Analysis. Sports Medicine. 2016;46(11):1689-1697.",
                                    url: "https://pubmed.ncbi.nlm.nih.gov/27102172/"
                                ),
                                Citation(
                                    text: "American College of Sports Medicine. Physical Activity Guidelines and Resources.",
                                    url: "https://acsm.org/education-resources/trending-topics-resources/physical-activity-guidelines/"
                                )
                            ]
                        )

                        SourceSection(
                            title: "Body Fat and Physique Scores",
                            method: "Body fat percentage, physique scores, symmetry, leanness and proportion ratings are visual estimates generated by an AI model from your photos. They are NOT clinical measurements. Methods such as DEXA, hydrostatic weighing or air displacement plethysmography are required for accurate body composition measurement, and their results will differ from Morph's estimates.",
                            citations: [
                                Citation(
                                    text: "National Institutes of Health. Assessing Your Weight and Health Risk.",
                                    url: "https://www.nhlbi.nih.gov/health/educational/lose_wt/risk.htm"
                                )
                            ]
                        )

                        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                            Text("IMPORTANT")
                                .font(MorphFonts.caption(11))
                                .foregroundColor(MorphColors.warning)
                                .tracking(1.5)

                            Text("Morph provides general fitness and nutrition information for educational purposes only. It is not medical advice, and it does not diagnose, treat, or prevent any condition. AI-generated scores and estimates are approximations, not clinical measurements. Consult a qualified physician, registered dietitian, or certified trainer before making significant changes to your diet or exercise routine, particularly if you have any medical condition, are pregnant, or are under 18.")
                                .font(MorphFonts.body(13))
                                .foregroundColor(MorphColors.textSecondary)
                        }
                        .padding(MorphSpacing.md)
                        .morphCard()

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, MorphSpacing.xl)
                }
            }
            .navigationTitle("Sources & Methodology")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MorphColors.accent)
                }
            }
        }
        .presentationBackground(MorphColors.background)
    }
}

private struct Citation {
    let text: String
    let url: String
}

private struct SourceSection: View {
    let title: String
    let method: String
    let citations: [Citation]

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
            Text(title.uppercased())
                .font(MorphFonts.caption(11))
                .foregroundColor(MorphColors.accent)
                .tracking(1.5)

            Text(method)
                .font(MorphFonts.body(14))
                .foregroundColor(MorphColors.textPrimary)

            ForEach(citations.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(citations[i].text)
                        .font(MorphFonts.caption(12))
                        .foregroundColor(MorphColors.textSecondary)

                    if let url = URL(string: citations[i].url) {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text("View source")
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(MorphFonts.caption(12))
                            .foregroundColor(MorphColors.accent)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MorphSpacing.md)
        .morphCard()
    }
}
