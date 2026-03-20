//
//  ClaudeService.swift
//  DOSBTS
//

import Foundation
import UIKit

// MARK: - FoodAnalysisResult

/// Wraps NutritionEstimate with the raw assistant JSON for multi-turn follow-up
struct FoodAnalysisResult {
    let estimate: NutritionEstimate
    let rawAssistantJSON: String // Raw JSON text for passing back in follow-up
}

// MARK: - ClaudeService

struct ClaudeService {
    // MARK: Internal

    static let keychainKey = "anthropic-api-key"
    static let model = "claude-haiku-4-5-20251001"

    func analyzeFood(imageData: Data, thumbWidthMM: Double? = nil, personalFoods: [PersonalFood] = [], recentCorrections: [FoodCorrection] = []) async throws -> NutritionEstimate {
        let apiKey = try getAPIKey()

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let base64Image = imageData.base64EncodedString()
        let mediaType = detectMediaType(data: imageData)

        let body: [String: Any] = [
            "model": ClaudeService.model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": mediaType,
                        "data": base64Image,
                    ]],
                    ["type": "text", "text": buildPrompt(thumbWidthMM: thumbWidthMM, personalFoods: personalFoods, recentCorrections: recentCorrections)],
                ]],
            ],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": nutritionSchema,
                ],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    func analyzeFoodText(query: String, personalFoods: [PersonalFood] = [], history: [ConversationTurn] = []) async throws -> FoodAnalysisResult {
        let apiKey = try getAPIKey()

        // Defence-in-depth: cap query length at service layer too
        let boundedQuery = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard boundedQuery.count >= 3 || !history.isEmpty else {
            throw ClaudeError.invalidResponse
        }

        // Cap total history at 4000 chars to prevent runaway API spend
        let totalHistoryChars = history.reduce(0) { $0 + $1.content.count }
        guard totalHistoryChars <= 4000 else {
            throw ClaudeError.invalidResponse
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build messages array — single-turn or multi-turn
        var messages: [[String: Any]]
        if history.isEmpty {
            // Single-turn: original query with system prompt
            messages = [
                ["role": "user", "content": buildTextPrompt(query: boundedQuery, personalFoods: personalFoods)],
            ]
        } else {
            // Multi-turn: replay conversation history verbatim (view owns all appends)
            messages = history.map { turn in
                ["role": turn.role, "content": turn.content] as [String: Any]
            }
        }

        let body: [String: Any] = [
            "model": ClaudeService.model,
            "max_tokens": 1024,
            "messages": messages,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": textNutritionSchema,
                ],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        return try handleResponseWithRawText(data: data, response: response)
    }

    func validateAPIKey(_ apiKey: String) async throws {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": ClaudeService.model,
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "hi"],
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return // Valid
        case 401:
            throw ClaudeError.invalidAPIKey
        case 429:
            return // Rate limited means key is valid
        default:
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: Private

    private var baseURL: URL {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            preconditionFailure("Invalid Anthropic API URL")
        }
        return url
    }

    private let nutritionSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "description": ["type": "string", "description": "Brief meal description"],
            "items": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "name": ["type": "string"],
                    "carbs_g": ["type": "number"],
                    "protein_g": ["type": "number"],
                    "fat_g": ["type": "number"],
                    "calories": ["type": "number"],
                    "fiber_g": ["type": "number"],
                    "serving_size": ["type": "string", "description": "Estimated portion size"],
                ],
                "required": ["name", "carbs_g"],
                "additionalProperties": false,
            ]],
            "total_carbs_g": ["type": "number"],
            "total_calories": ["type": "number"],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "confidence_notes": ["type": "string", "description": "Why confidence is high/medium/low"],
        ],
        "required": ["description", "items", "total_carbs_g", "confidence"],
        "additionalProperties": false,
    ]

    // Text-specific schema: adds `reasoning` field for CoT before numbers
    private let textNutritionSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "reasoning": ["type": "string", "description": "Step-by-step identification of each food item, data source used, and portion assumptions"],
            "description": ["type": "string", "description": "Brief meal description"],
            "items": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "name": ["type": "string"],
                    "carbs_g": ["type": "number"],
                    "protein_g": ["type": "number"],
                    "fat_g": ["type": "number"],
                    "calories": ["type": "number"],
                    "fiber_g": ["type": "number"],
                    "serving_size": ["type": "string", "description": "Portion description e.g. '1 medium (154g)' or '200ml'"],
                ],
                "required": ["name", "carbs_g"],
                "additionalProperties": false,
            ]],
            "total_carbs_g": ["type": "number"],
            "total_calories": ["type": "number"],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "confidence_notes": ["type": "string", "description": "Why confidence is high/medium/low"],
        ],
        "required": ["reasoning", "description", "items", "total_carbs_g", "confidence"],
        "additionalProperties": false,
    ]

    private func buildTextPrompt(query: String, personalFoods: [PersonalFood] = []) -> String {
        var prompt = """
        You are a registered dietitian AI assistant. Given a food description, identify each distinct food item and estimate nutritional content.

        <resolution_protocol>
        - Named restaurant items ("Big Mac", "Grande Latte"): use the brand's published nutrition data.
        - Named packaged products ("Ben & Jerry's Cookies & Cream"): use standard serving or stated size.
        - Metric quantities (200ml, 100g): use as stated.
        - Informal quantities: "a couple" = 2, "a few" = 3, "a handful" of nuts = 28g, "a slice" of bread = 28g, pizza = 100g, "a cup" = 240ml liquid.
        - "small/medium/large" at a restaurant: match the chain's published size tiers.
        - Multi-item meals ("burger fries and a coke"): decompose into separate items.
        - When quantity is unclear: assume one standard serving and note the assumption in confidence_notes.
        </resolution_protocol>

        <confidence_definitions>
        "high": Specific branded/restaurant product with known nutrition, or precise metric quantities for common foods. Error < 15%.
        "medium": Recognized food type but brand is generic, quantity informal, or cooking method unclear. Error 15-35%.
        "low": Ambiguous food, very vague quantity, unusual/regional item, or combining multiple assumptions. Error > 35%.
        When in doubt between two levels, choose the lower one.
        </confidence_definitions>
        """

        // User query wrapped in XML element for structural isolation
        let sanitizedQuery = sanitizeFoodName(query)
        prompt += "\n\n<food_description>\(sanitizedQuery)</food_description>"

        // Personal food dictionary (max 50 entries)
        if !personalFoods.isEmpty {
            let entries = personalFoods.prefix(50).map { "- \(sanitizeFoodName($0.name)): \(Int($0.carbsG))g carbs" }.joined(separator: "\n")
            prompt += "\n\n<user_food_dictionary>\nThese are this user's confirmed foods. Use these exact values when identified:\n\(entries)\n</user_food_dictionary>"
        }

        return prompt
    }

    private func buildPrompt(thumbWidthMM: Double?, personalFoods: [PersonalFood] = [], recentCorrections: [FoodCorrection] = []) -> String {
        var prompt = "Analyze this meal photo. Identify each food item and estimate nutritional content. Be specific about portion sizes."
        if let mm = thumbWidthMM {
            prompt += " The user's thumb (width: \(Int(mm))mm at the widest joint) may be visible in the photo next to the food as a size reference. If you can see a thumb, use its known width to estimate portion sizes more accurately. The thumb should be at the same depth as the food for reliable scale."
        }

        // Personal food dictionary
        if !personalFoods.isEmpty {
            let entries = personalFoods.prefix(50).map { "- \(sanitizeFoodName($0.name)): \(Int($0.carbsG))g carbs" }.joined(separator: "\n")
            prompt += "\n\n<user_food_dictionary>\nThese are this user's confirmed foods. Use these exact values when identified:\n\(entries)\n</user_food_dictionary>"
        }

        // Recent corrections with lessons
        let positiveCorrections = recentCorrections.filter { $0.correctionType != .deleted }
        if !positiveCorrections.isEmpty {
            var examples = ""
            for correction in positiveCorrections {
                let aiSaid = sanitizeFoodName(correction.originalName ?? "unknown")
                let userCorrected = sanitizeFoodName(correction.correctedName ?? "unknown")
                examples += "\n<example>\n  <ai_said>\(aiSaid)</ai_said>\n  <user_corrected>\(userCorrected)</user_corrected>\n</example>"
            }
            prompt += "\n\n<user_corrections>\nThis user has corrected these misidentifications:\(examples)\n</user_corrections>"
        }

        // Negative examples (hallucinated items)
        let deletedCorrections = recentCorrections.filter { $0.correctionType == .deleted }
        if !deletedCorrections.isEmpty {
            let items = deletedCorrections.prefix(5).map { correction in
                let name = sanitizeFoodName(correction.originalName ?? "unknown")
                return "<excluded_item>\n  <name>\(name)</name>\n</excluded_item>"
            }.joined(separator: "\n")
            prompt += "\n\n<items_not_present>\nDo not include these items unless you see unmistakable visual evidence:\n\(items)\n</items_not_present>"
        }

        return prompt
    }

    private func sanitizeFoodName(_ name: String) -> String {
        String(name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(100))
    }

    private func getAPIKey() throws -> String {
        guard let apiKey = KeychainService.read(key: ClaudeService.keychainKey),
              !apiKey.isEmpty
        else {
            throw ClaudeError.invalidAPIKey
        }
        return apiKey
    }

    private func detectMediaType(data: Data) -> String {
        let bytes = [UInt8](data.prefix(4))
        if bytes.count >= 3, bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF {
            return "image/jpeg"
        }
        if bytes.count >= 4, bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47 {
            return "image/png"
        }
        if bytes.count >= 3, bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46 {
            return "image/gif"
        }
        return "image/jpeg"
    }

    private func handleResponseWithRawText(data: Data, response: URLResponse) throws -> FoodAnalysisResult {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            let rawText = claudeResponse.content.first(where: { $0.type == "text" })?.text ?? ""
            let estimate = try claudeResponse.toNutritionEstimate()
            return FoodAnalysisResult(estimate: estimate, rawAssistantJSON: rawText)
        case 401:
            throw ClaudeError.invalidAPIKey
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                .flatMap { TimeInterval($0) } ?? 60
            throw ClaudeError.rateLimited(retryAfter: retryAfter)
        case 529:
            throw ClaudeError.overloaded
        default:
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> NutritionEstimate {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return try claudeResponse.toNutritionEstimate()

        case 401:
            throw ClaudeError.invalidAPIKey

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                .flatMap { TimeInterval($0) } ?? 60
            throw ClaudeError.rateLimited(retryAfter: retryAfter)

        case 529:
            throw ClaudeError.overloaded

        default:
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - ClaudeResponse

private struct ClaudeResponse: Codable {
    var content: [ContentBlock]

    struct ContentBlock: Codable {
        var type: String
        var text: String?
    }

    func toNutritionEstimate() throws -> NutritionEstimate {
        guard let textBlock = content.first(where: { $0.type == "text" }),
              let text = textBlock.text,
              let data = text.data(using: .utf8)
        else {
            throw ClaudeError.invalidResponse
        }

        return try JSONDecoder().decode(NutritionEstimate.self, from: data)
    }
}

// MARK: - UIImage extension

extension UIImage {
    func preparedForVisionAPI(maxDimension: CGFloat = 1024) -> Data? {
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.jpegData(withCompressionQuality: 0.7) { context in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
