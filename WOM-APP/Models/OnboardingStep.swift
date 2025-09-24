import Foundation

struct OnboardingStep: Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let order: Int
    
    // Predefined onboarding steps
    static let birthdayStep = OnboardingStep(id: "birthday", title: "Birthday", isCompleted: false, order: 1)
    static let nameUsernameStep = OnboardingStep(id: "name_username", title: "Name & Username", isCompleted: false, order: 2)
    static let serviceSelectionStep = OnboardingStep(id: "service_selection", title: "Service Selection", isCompleted: false, order: 3)
    static let locationPermissionStep = OnboardingStep(id: "location_permission", title: "Location Permission", isCompleted: false, order: 4)
    static let businessSelectionStep = OnboardingStep(id: "business_selection", title: "Business Selection", isCompleted: false, order: 5)
    
    // Default onboarding steps
    static let defaultSteps: [OnboardingStep] = [
        birthdayStep,
        nameUsernameStep,
        serviceSelectionStep,
        locationPermissionStep,
        businessSelectionStep
    ]
}

struct OnboardingProgress: Codable {
    var steps: [OnboardingStep]
    var currentStepIndex: Int
    var isCompleted: Bool
    
    init() {
        self.steps = OnboardingStep.defaultSteps
        self.currentStepIndex = 0
        self.isCompleted = false
    }
    
    var currentStep: OnboardingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var nextIncompleteStep: OnboardingStep? {
        return steps.first { !$0.isCompleted }
    }
    
    mutating func completeStep(stepId: String) {
        if let index = steps.firstIndex(where: { $0.id == stepId }) {
            steps[index] = OnboardingStep(
                id: steps[index].id,
                title: steps[index].title,
                isCompleted: true,
                order: steps[index].order
            )
            
            // Move to next incomplete step
            if let nextStep = nextIncompleteStep {
                currentStepIndex = steps.firstIndex(where: { $0.id == nextStep.id }) ?? currentStepIndex
            } else {
                // All steps completed
                isCompleted = true
            }
        }
    }
    
    func toDictionary() -> [String: Any] {
        [
            "steps": steps.map { step in
                [
                    "id": step.id,
                    "title": step.title,
                    "isCompleted": step.isCompleted,
                    "order": step.order
                ]
            },
            "currentStepIndex": currentStepIndex,
            "isCompleted": isCompleted
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> OnboardingProgress {
        var progress = OnboardingProgress()
        
        if let stepsData = dict["steps"] as? [[String: Any]] {
            progress.steps = stepsData.compactMap { stepDict in
                guard let id = stepDict["id"] as? String,
                      let title = stepDict["title"] as? String,
                      let isCompleted = stepDict["isCompleted"] as? Bool,
                      let order = stepDict["order"] as? Int else {
                    return nil
                }
                return OnboardingStep(id: id, title: title, isCompleted: isCompleted, order: order)
            }
        }
        
        progress.currentStepIndex = dict["currentStepIndex"] as? Int ?? 0
        progress.isCompleted = dict["isCompleted"] as? Bool ?? false
        
        return progress
    }
}
