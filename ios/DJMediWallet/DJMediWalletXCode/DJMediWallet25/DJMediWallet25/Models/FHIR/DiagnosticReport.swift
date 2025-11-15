import Foundation

public struct DiagnosticReport: Codable {
    public let resourceType: String
    public let id: String?
    public let status: String
    public let code: CodeableConcept
    public let subject: Reference?
    public let effectiveDateTime: String?
    public let issued: String?
    public let performer: [Reference]?
    public let result: [Reference]?
    public let conclusion: String?
    public let presentedForm: [Attachment]?

    public init(
        id: String? = nil,
        status: String,
        code: CodeableConcept,
        subject: Reference? = nil,
        effectiveDateTime: String? = nil,
        issued: String? = nil,
        performer: [Reference]? = nil,
        result: [Reference]? = nil,
        conclusion: String? = nil,
        presentedForm: [Attachment]? = nil
    ) {
        self.resourceType = "DiagnosticReport"
        self.id = id
        self.status = status
        self.code = code
        self.subject = subject
        self.effectiveDateTime = effectiveDateTime
        self.issued = issued
        self.performer = performer
        self.result = result
        self.conclusion = conclusion
        self.presentedForm = presentedForm
    }
}

public struct Attachment: Codable {
    public let contentType: String?
    public let language: String?
    public let data: String?
    public let title: String?
    public let creation: String?

    public init(
        contentType: String? = nil,
        language: String? = nil,
        data: String? = nil,
        title: String? = nil,
        creation: String? = nil
    ) {
        self.contentType = contentType
        self.language = language
        self.data = data
        self.title = title
        self.creation = creation
    }
}
