/*
 REQVIORA G1 logical SQL Server foundation — CANDIDATE DDL, not an executed migration.
 Existing source documents propose SQL Server/EF Core; provider choice remains subject to review.
 Apply through reviewed EF migrations, not direct production execution.
 Services MUST enforce composite ProjectId scope, membership, field-level RBAC, and transactions.
 */
SET XACT_ABORT ON;
GO
IF SCHEMA_ID(N'reqviora') IS NULL EXEC(N'CREATE SCHEMA reqviora');
GO
CREATE TABLE reqviora.Accounts (
  UserId uniqueidentifier NOT NULL PRIMARY KEY,
  ExternalSubject nvarchar(255) NOT NULL UNIQUE,
  NormalizedEmail nvarchar(320) NULL,
  IsVerified bit NOT NULL DEFAULT (0),
  Status varchar(16) NOT NULL DEFAULT ('active') CHECK (Status IN ('active','suspended','disabled')),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RowVer rowversion NOT NULL
);
GO
CREATE TABLE reqviora.Projects (
  ProjectId uniqueidentifier NOT NULL PRIMARY KEY,
  Name nvarchar(160) NOT NULL,
  Category nvarchar(120) NULL,
  CreatedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  Status varchar(12) NOT NULL DEFAULT ('active') CHECK (Status IN ('active','archived')),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  UpdatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RowVer rowversion NOT NULL
);
CREATE TABLE reqviora.ProjectMemberships (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  UserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  Status varchar(16) NOT NULL CHECK (Status IN ('invited','active','revoked')),
  JoinedAt datetimeoffset NULL,
  RevokedAt datetimeoffset NULL,
  CONSTRAINT PK_ProjectMemberships PRIMARY KEY(ProjectId,UserId)
);
CREATE TABLE reqviora.ProjectMemberRoles (
  ProjectId uniqueidentifier NOT NULL,
  UserId uniqueidentifier NOT NULL,
  RoleCode varchar(24) NOT NULL CHECK (RoleCode IN ('Owner','RequirementsEditor','Designer','Reviewer','Approver','Viewer')),
  GrantedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  GrantedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_ProjectMemberRoles PRIMARY KEY(ProjectId,UserId,RoleCode),
  CONSTRAINT FK_MemberRole_Membership FOREIGN KEY(ProjectId,UserId) REFERENCES reqviora.ProjectMemberships(ProjectId,UserId)
);
GO
CREATE TABLE reqviora.PlatformAdminAssignments (
  UserId uniqueidentifier NOT NULL PRIMARY KEY REFERENCES reqviora.Accounts(UserId),
  AssignedByUserId uniqueidentifier NULL REFERENCES reqviora.Accounts(UserId),
  AssignedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RevokedAt datetimeoffset NULL
);
CREATE TABLE reqviora.ProjectInvitations (
  InvitationId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  InviteeEmailNormalized nvarchar(320) NOT NULL,
  InvitedRolesJson nvarchar(max) NOT NULL CHECK (ISJSON(InvitedRolesJson) = 1),
  TokenHash char(64) NOT NULL UNIQUE,
  ExpiresAt datetimeoffset NOT NULL,
  AcceptedByUserId uniqueidentifier NULL REFERENCES reqviora.Accounts(UserId),
  AcceptedAt datetimeoffset NULL,
  RevokedAt datetimeoffset NULL
);

CREATE TABLE reqviora.ProjectDrafts (
  DraftId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  DraftVersion bigint NOT NULL DEFAULT(1) CHECK (DraftVersion > 0),
  Status varchar(16) NOT NULL DEFAULT ('active') CHECK (Status IN ('active','superseded','archived')),
  ProjectSchemaVersion varchar(40) NOT NULL,
  DraftJson nvarchar(max) NOT NULL CHECK (ISJSON(DraftJson) = 1),
  DraftSha256 char(64) NOT NULL,
  UpdatedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  UpdatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RowVer rowversion NOT NULL,
  CONSTRAINT UQ_ProjectDraftScope UNIQUE(ProjectId,DraftId)
);
CREATE UNIQUE INDEX UX_OneActiveDraftPerProject ON reqviora.ProjectDrafts(ProjectId) WHERE Status = 'active';
CREATE TABLE reqviora.BuilderSteps (
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  StepNo tinyint NOT NULL CHECK (StepNo BETWEEN 1 AND 8),
  StepStatus varchar(24) NOT NULL CHECK (StepStatus IN ('not-started','in-progress','needs-review','complete')),
  StepSchemaVersion varchar(40) NOT NULL,
  StepJson nvarchar(max) NOT NULL CHECK (ISJSON(StepJson) = 1),
  UpdatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RowVer rowversion NOT NULL,
  CONSTRAINT PK_BuilderSteps PRIMARY KEY(DraftId,StepNo),
  CONSTRAINT FK_BuilderStep_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId)
);
GO
CREATE TABLE reqviora.ProjectSources (
  SourceId uniqueidentifier NOT NULL,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  Kind varchar(12) NOT NULL CHECK (Kind IN ('pdf','docx','txt','voice','text','manual')),
  ProcessingStatus varchar(16) NOT NULL CHECK (ProcessingStatus IN ('pending','processing','ready','partial','failed','removed')),
  OriginalName nvarchar(255) NULL,
  MediaType nvarchar(120) NULL,
  PrivateObjectKey nvarchar(800) NULL,
  Sha256 char(64) NULL,
  ConsentRecordId uniqueidentifier NULL,
  RemovedAt datetimeoffset NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_ProjectSources PRIMARY KEY(ProjectId,SourceId)
);
CREATE TABLE reqviora.SourceSegments (
  ProjectId uniqueidentifier NOT NULL,
  SourceId uniqueidentifier NOT NULL,
  SegmentId uniqueidentifier NOT NULL,
  SegmentOrdinal int NOT NULL CHECK (SegmentOrdinal >= 0),
  PageNumber int NULL CHECK (PageNumber > 0),
  SegmentText nvarchar(max) NULL,
  CONSTRAINT PK_SourceSegments PRIMARY KEY(ProjectId,SegmentId),
  CONSTRAINT FK_Segment_Source FOREIGN KEY(ProjectId,SourceId) REFERENCES reqviora.ProjectSources(ProjectId,SourceId)
);
CREATE TABLE reqviora.Transcripts (
  TranscriptId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  SourceId uniqueidentifier NOT NULL,
  Locale varchar(12) NOT NULL CHECK (Locale IN ('ta','en','mixed')),
  TranscriptText nvarchar(max) NOT NULL,
  IsUserCorrected bit NOT NULL DEFAULT 0,
  CorrectedByUserId uniqueidentifier NULL REFERENCES reqviora.Accounts(UserId),
  CorrectedAt datetimeoffset NULL,
  CONSTRAINT FK_Transcript_Source FOREIGN KEY(ProjectId,SourceId) REFERENCES reqviora.ProjectSources(ProjectId,SourceId)
);

CREATE TABLE reqviora.CandidateClaims (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  CandidateId uniqueidentifier NOT NULL,
  ClaimType varchar(32) NOT NULL,
  ClaimText nvarchar(max) NOT NULL,
  ReviewStatus varchar(16) NOT NULL CHECK (ReviewStatus IN ('suggested','confirmed','rejected','deferred')),
  ConfirmedByUserId uniqueidentifier NULL REFERENCES reqviora.Accounts(UserId),
  ConfirmedAt datetimeoffset NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT PK_CandidateClaims PRIMARY KEY(ProjectId,CandidateId),
  CONSTRAINT CK_ClaimConfirmedBy CHECK (ReviewStatus <> 'confirmed' OR (ConfirmedByUserId IS NOT NULL AND ConfirmedAt IS NOT NULL))
);
CREATE TABLE reqviora.CandidateEvidence (
  ProjectId uniqueidentifier NOT NULL,
  CandidateId uniqueidentifier NOT NULL,
  SegmentId uniqueidentifier NOT NULL,
  CONSTRAINT PK_CandidateEvidence PRIMARY KEY(ProjectId,CandidateId,SegmentId),
  CONSTRAINT FK_Evidence_Claim FOREIGN KEY(ProjectId,CandidateId) REFERENCES reqviora.CandidateClaims(ProjectId,CandidateId),
  CONSTRAINT FK_Evidence_Segment FOREIGN KEY(ProjectId,SegmentId) REFERENCES reqviora.SourceSegments(ProjectId,SegmentId)
);
CREATE TABLE reqviora.ConfirmationDecisions (
  DecisionId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  CandidateId uniqueidentifier NOT NULL,
  ActorUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  Decision varchar(20) NOT NULL CHECK (Decision IN ('confirm','reject','defer','propose-edit')),
  DecisionAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  Note nvarchar(3000) NULL,
  CONSTRAINT FK_DecisionClaim FOREIGN KEY(ProjectId,CandidateId) REFERENCES reqviora.CandidateClaims(ProjectId,CandidateId)
);
GO
CREATE TABLE reqviora.Requirements (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  RequirementId uniqueidentifier NOT NULL,
  Title nvarchar(300) NOT NULL,
  Status varchar(16) NOT NULL CHECK (Status IN ('proposed','confirmed','deferred','rejected')),
  SourceCandidateId uniqueidentifier NULL,
  CONSTRAINT PK_Requirements PRIMARY KEY(ProjectId,RequirementId),
  CONSTRAINT FK_Requirement_Candidate FOREIGN KEY(ProjectId,SourceCandidateId) REFERENCES reqviora.CandidateClaims(ProjectId,CandidateId)
);
CREATE TABLE reqviora.Features (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  FeatureId uniqueidentifier NOT NULL,
  Title nvarchar(300) NOT NULL,
  Priority varchar(6) NOT NULL CHECK (Priority IN ('must','should','could','wont')),
  Status varchar(16) NOT NULL CHECK (Status IN ('proposed','confirmed','deferred','rejected')),
  CONSTRAINT PK_Features PRIMARY KEY(ProjectId,FeatureId)
);
CREATE TABLE reqviora.AcceptanceCriteria (
  ProjectId uniqueidentifier NOT NULL,
  FeatureId uniqueidentifier NOT NULL,
  CriterionId uniqueidentifier NOT NULL,
  CriterionText nvarchar(max) NOT NULL,
  IsRequired bit NOT NULL DEFAULT 1,
  CONSTRAINT PK_AcceptanceCriteria PRIMARY KEY(ProjectId,CriterionId),
  CONSTRAINT FK_Criterion_Feature FOREIGN KEY(ProjectId,FeatureId) REFERENCES reqviora.Features(ProjectId,FeatureId)
);

CREATE TABLE reqviora.RequirementFeatures (
  ProjectId uniqueidentifier NOT NULL,
  RequirementId uniqueidentifier NOT NULL,
  FeatureId uniqueidentifier NOT NULL,
  CONSTRAINT PK_RequirementFeatures PRIMARY KEY(ProjectId,RequirementId,FeatureId),
  CONSTRAINT FK_RF_Requirement FOREIGN KEY(ProjectId,RequirementId) REFERENCES reqviora.Requirements(ProjectId,RequirementId),
  CONSTRAINT FK_RF_Feature FOREIGN KEY(ProjectId,FeatureId) REFERENCES reqviora.Features(ProjectId,FeatureId)
);
CREATE TABLE reqviora.ApplicationRoles (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  ApplicationRoleId uniqueidentifier NOT NULL,
  DisplayName nvarchar(160) NOT NULL,
  CONSTRAINT PK_ApplicationRoles PRIMARY KEY(ProjectId,ApplicationRoleId)
);
CREATE TABLE reqviora.Screens (
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  ScreenId uniqueidentifier NOT NULL,
  Name nvarchar(300) NOT NULL,
  Purpose nvarchar(2000) NULL,
  SelectionStatus varchar(12) NOT NULL CHECK (SelectionStatus IN ('selected','suggested','excluded')),
  IsRequired bit NOT NULL,
  CONSTRAINT PK_Screens PRIMARY KEY(ProjectId,ScreenId)
);
CREATE TABLE reqviora.GraphLayouts (
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  ScreenId uniqueidentifier NOT NULL,
  PositionX float NOT NULL,
  PositionY float NOT NULL,
  CONSTRAINT PK_GraphLayouts PRIMARY KEY(DraftId,ScreenId),
  CONSTRAINT FK_GraphLayout_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId),
  CONSTRAINT FK_GraphLayout_Screen FOREIGN KEY(ProjectId,ScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId)
);

CREATE TABLE reqviora.FeatureScreens (
  ProjectId uniqueidentifier NOT NULL,
  FeatureId uniqueidentifier NOT NULL,
  ScreenId uniqueidentifier NOT NULL,
  CONSTRAINT PK_FeatureScreens PRIMARY KEY(ProjectId,FeatureId,ScreenId),
  CONSTRAINT FK_FS_Feature FOREIGN KEY(ProjectId,FeatureId) REFERENCES reqviora.Features(ProjectId,FeatureId),
  CONSTRAINT FK_FS_Screen FOREIGN KEY(ProjectId,ScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId)
);
CREATE TABLE reqviora.ScreenActions (
  ProjectId uniqueidentifier NOT NULL,
  ActionId uniqueidentifier NOT NULL,
  SourceScreenId uniqueidentifier NOT NULL,
  Kind varchar(24) NOT NULL CHECK (Kind IN ('navigate','openModal','closeModal','setMockState','submitMockForm','showMessage','simulateError','simulateLoading')),
  ParamsJson nvarchar(max) NOT NULL CHECK (ISJSON(ParamsJson) = 1),
  CONSTRAINT PK_ScreenActions PRIMARY KEY(ProjectId,ActionId),
  CONSTRAINT FK_Action_Source FOREIGN KEY(ProjectId,SourceScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId)
);
CREATE TABLE reqviora.NavigationRoutes (
  ProjectId uniqueidentifier NOT NULL,
  RouteId uniqueidentifier NOT NULL,
  SourceScreenId uniqueidentifier NOT NULL,
  TargetScreenId uniqueidentifier NOT NULL,
  TriggerActionId uniqueidentifier NOT NULL,
  ConditionJson nvarchar(max) NOT NULL CHECK (ISJSON(ConditionJson) = 1),
  IsEnabled bit NOT NULL DEFAULT 1,
  CONSTRAINT PK_NavigationRoutes PRIMARY KEY(ProjectId,RouteId),
  CONSTRAINT FK_Route_Source FOREIGN KEY(ProjectId,SourceScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId),
  CONSTRAINT FK_Route_Target FOREIGN KEY(ProjectId,TargetScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId),
  CONSTRAINT FK_Route_Action FOREIGN KEY(ProjectId,TriggerActionId) REFERENCES reqviora.ScreenActions(ProjectId,ActionId)
);
CREATE TABLE reqviora.ComponentInstances (
  ProjectId uniqueidentifier NOT NULL,
  ComponentInstanceId uniqueidentifier NOT NULL,
  ScreenId uniqueidentifier NOT NULL,
  ParentComponentInstanceId uniqueidentifier NULL,
  ComponentType varchar(32) NOT NULL,
  RegistryVersion varchar(40) NOT NULL,
  PropsJson nvarchar(max) NOT NULL CHECK (ISJSON(PropsJson) = 1),
  PositionOrdinal int NOT NULL CHECK (PositionOrdinal >= 0),
  CONSTRAINT PK_ComponentInstances PRIMARY KEY(ProjectId,ComponentInstanceId),
  CONSTRAINT FK_Component_Screen FOREIGN KEY(ProjectId,ScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId),
  CONSTRAINT FK_Component_Parent FOREIGN KEY(ProjectId,ParentComponentInstanceId) REFERENCES reqviora.ComponentInstances(ProjectId,ComponentInstanceId)
);
CREATE TABLE reqviora.TraceLinks (
  ProjectId uniqueidentifier NOT NULL,
  TraceLinkId uniqueidentifier NOT NULL,
  RequirementId uniqueidentifier NOT NULL,
  FeatureId uniqueidentifier NOT NULL,
  ScreenId uniqueidentifier NOT NULL,
  ActionId uniqueidentifier NULL,
  CriterionId uniqueidentifier NULL,
  CONSTRAINT PK_TraceLinks PRIMARY KEY(ProjectId,TraceLinkId),
  CONSTRAINT FK_Trace_Req FOREIGN KEY(ProjectId,RequirementId) REFERENCES reqviora.Requirements(ProjectId,RequirementId),
  CONSTRAINT FK_Trace_Feature FOREIGN KEY(ProjectId,FeatureId) REFERENCES reqviora.Features(ProjectId,FeatureId),
  CONSTRAINT FK_Trace_Screen FOREIGN KEY(ProjectId,ScreenId) REFERENCES reqviora.Screens(ProjectId,ScreenId),
  CONSTRAINT FK_Trace_Action FOREIGN KEY(ProjectId,ActionId) REFERENCES reqviora.ScreenActions(ProjectId,ActionId),
  CONSTRAINT FK_Trace_Criterion FOREIGN KEY(ProjectId,CriterionId) REFERENCES reqviora.AcceptanceCriteria(ProjectId,CriterionId)
);
GO
CREATE TABLE reqviora.BlueprintVersions (
  BlueprintId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  DraftVersion bigint NOT NULL,
  SchemaVersion varchar(40) NOT NULL,
  RegistryVersion varchar(40) NOT NULL,
  BlueprintJson nvarchar(max) NOT NULL CHECK (ISJSON(BlueprintJson) = 1),
  ContentSha256 char(64) NOT NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Blueprint_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId)
);
CREATE TABLE reqviora.DesignRevisions (
  DesignRevisionId uniqueidentifier NOT NULL PRIMARY KEY,
  BlueprintId uniqueidentifier NOT NULL REFERENCES reqviora.BlueprintVersions(BlueprintId),
  ParentDesignRevisionId uniqueidentifier NULL REFERENCES reqviora.DesignRevisions(DesignRevisionId),
  RevisionNumber bigint NOT NULL CHECK (RevisionNumber >= 1),
  DesignJson nvarchar(max) NOT NULL CHECK (ISJSON(DesignJson) = 1),
  ContentSha256 char(64) NOT NULL,
  CreatedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_DesignRev_Blueprint_Number UNIQUE(BlueprintId,RevisionNumber)
);

CREATE TABLE reqviora.EditEvents (
  EditEventId uniqueidentifier NOT NULL PRIMARY KEY,
  BlueprintId uniqueidentifier NOT NULL REFERENCES reqviora.BlueprintVersions(BlueprintId),
  ActorUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  EventJson nvarchar(max) NOT NULL CHECK (ISJSON(EventJson) = 1),
  IsMaterial bit NOT NULL DEFAULT(1),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME()
);
CREATE TABLE reqviora.ValidationRuns (
  ValidationRunId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  DraftVersion bigint NOT NULL,
  DraftSha256 char(64) NOT NULL,
  ValidatorVersion varchar(40) NOT NULL,
  Status varchar(12) NOT NULL CHECK (Status IN ('ready','blocked')),
  Blockers int NOT NULL CHECK (Blockers >= 0),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Validation_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId)
);
CREATE TABLE reqviora.ValidationFindings (
  FindingId uniqueidentifier NOT NULL PRIMARY KEY,
  ValidationRunId uniqueidentifier NOT NULL REFERENCES reqviora.ValidationRuns(ValidationRunId),
  RuleId varchar(100) NOT NULL,
  Severity varchar(12) NOT NULL CHECK (Severity IN ('blocker','advisory')),
  ObjectId uniqueidentifier NULL,
  Message nvarchar(1500) NOT NULL
);
CREATE TABLE reqviora.ReviewEvents (
  ReviewEventId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  DraftVersion bigint NOT NULL,
  ActorUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  EventType varchar(20) NOT NULL CHECK (EventType IN ('comment','request-changes')),
  CommentText nvarchar(max) NOT NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Review_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId)
);
CREATE TABLE reqviora.MaterialContributions (
  ContributionId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  DraftId uniqueidentifier NOT NULL,
  DraftVersion bigint NOT NULL,
  ActorUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  ObjectId uniqueidentifier NULL,
  ChangeCategory varchar(60) NOT NULL,
  IsMaterial bit NOT NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Contribution_Draft FOREIGN KEY(ProjectId,DraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId)
);

CREATE TABLE reqviora.ApprovedRevisions (
  RevisionId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  SourceDraftId uniqueidentifier NOT NULL,
  DraftVersion bigint NOT NULL,
  ValidationRunId uniqueidentifier NOT NULL REFERENCES reqviora.ValidationRuns(ValidationRunId),
  ApprovedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  SnapshotSchemaVersion varchar(40) NOT NULL,
  SnapshotJson nvarchar(max) NOT NULL CHECK (ISJSON(SnapshotJson) = 1),
  ContentSha256 char(64) NOT NULL,
  ApprovedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_Approved_SourceDraft FOREIGN KEY(ProjectId,SourceDraftId) REFERENCES reqviora.ProjectDrafts(ProjectId,DraftId),
  CONSTRAINT UQ_Approved_ExactDraft UNIQUE(ProjectId,SourceDraftId,DraftVersion)
);
CREATE TABLE reqviora.ApprovalEvents (
  ApprovalEventId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL,
  RevisionId uniqueidentifier NOT NULL REFERENCES reqviora.ApprovedRevisions(RevisionId),
  ActorUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  EventType varchar(24) NOT NULL CHECK (EventType IN ('approved','comment','changes-requested')),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
CREATE TABLE reqviora.ExportJobs (
  ExportId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  SourceRevisionId uniqueidentifier NULL REFERENCES reqviora.ApprovedRevisions(RevisionId),
  SourceDraftId uniqueidentifier NULL REFERENCES reqviora.ProjectDrafts(DraftId),
  SourceDraftVersion bigint NULL,
  PackageProfile varchar(20) NOT NULL CHECK (PackageProfile IN ('canonical19')),
  Status varchar(12) NOT NULL CHECK (Status IN ('queued','running','ready','failed')),
  PrivateObjectKey nvarchar(800) NULL,
  ManifestSha256 char(64) NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_Export_ExactlyOneSource CHECK ((SourceRevisionId IS NOT NULL AND SourceDraftId IS NULL AND SourceDraftVersion IS NULL) OR (SourceRevisionId IS NULL AND SourceDraftId IS NOT NULL AND SourceDraftVersion IS NOT NULL))
);
CREATE TABLE reqviora.ExportFiles (
  ExportId uniqueidentifier NOT NULL REFERENCES reqviora.ExportJobs(ExportId),
  FilePath nvarchar(300) NOT NULL,
  Bytes bigint NOT NULL CHECK (Bytes >= 0),
  Sha256 char(64) NOT NULL,
  CONSTRAINT PK_ExportFiles PRIMARY KEY(ExportId,FilePath)
);
CREATE TABLE reqviora.ViewerResourceGrants (
  ViewerGrantId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  ViewerUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  RevisionId uniqueidentifier NOT NULL REFERENCES reqviora.ApprovedRevisions(RevisionId),
  ResourceKind varchar(24) NOT NULL CHECK (ResourceKind IN ('screen','preview','document','revision','screen-group','export')),
  ResourceId uniqueidentifier NOT NULL,
  CanRead bit NOT NULL DEFAULT 1,
  CanDownload bit NOT NULL DEFAULT 0,
  ExpiresAt datetimeoffset NULL,
  RevokedAt datetimeoffset NULL,
  GrantedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId)
);
CREATE TABLE reqviora.ViewerGrantMembers (
  ViewerGrantId uniqueidentifier NOT NULL REFERENCES reqviora.ViewerResourceGrants(ViewerGrantId),
  ResourceKind varchar(24) NOT NULL,
  ResourceId uniqueidentifier NOT NULL,
  CONSTRAINT PK_ViewerGrantMembers PRIMARY KEY(ViewerGrantId,ResourceKind,ResourceId)
);
CREATE TABLE reqviora.McpGrants (
  GrantId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  RevisionId uniqueidentifier NOT NULL REFERENCES reqviora.ApprovedRevisions(RevisionId),
  ClientId uniqueidentifier NOT NULL,
  ScopesJson nvarchar(max) NOT NULL CHECK (ISJSON(ScopesJson) = 1),
  ExpiresAt datetimeoffset NOT NULL,
  RevokedAt datetimeoffset NULL,
  GrantedByUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId)
);
CREATE TABLE reqviora.ProcessingJobs (
  JobId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  Kind varchar(40) NOT NULL,
  Status varchar(16) NOT NULL CHECK (Status IN ('queued','running','partial','completed','failed','cancelled')),
  IdempotencyKey varchar(128) NOT NULL,
  InputSha256 char(64) NULL,
  AttemptCount int NOT NULL DEFAULT(0) CHECK (AttemptCount >= 0),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT UQ_ProcessingJobIdempotency UNIQUE(ProjectId,Kind,IdempotencyKey)
);
CREATE TABLE reqviora.ConsentRecords (
  ConsentId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  SubjectUserId uniqueidentifier NOT NULL REFERENCES reqviora.Accounts(UserId),
  PurposeCode varchar(80) NOT NULL,
  NoticeVersion varchar(40) NOT NULL,
  GrantedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  RevokedAt datetimeoffset NULL
);
CREATE TABLE reqviora.AIUsageEvents (
  UsageEventId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NOT NULL REFERENCES reqviora.Projects(ProjectId),
  JobId uniqueidentifier NULL,
  ProviderAlias varchar(80) NULL,
  MeteredUnits bigint NOT NULL DEFAULT 0,
  CostCurrency char(3) NULL,
  CostEstimate decimal(18,6) NULL,
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE reqviora.AuditEvents (
  AuditId uniqueidentifier NOT NULL PRIMARY KEY,
  ProjectId uniqueidentifier NULL REFERENCES reqviora.Projects(ProjectId),
  ActorUserId uniqueidentifier NULL REFERENCES reqviora.Accounts(UserId),
  ActorClientId uniqueidentifier NULL,
  ActionCode varchar(100) NOT NULL,
  TargetObjectId uniqueidentifier NULL,
  CorrelationId uniqueidentifier NOT NULL,
  SafeMetadataJson nvarchar(max) NULL CHECK (SafeMetadataJson IS NULL OR ISJSON(SafeMetadataJson) = 1),
  CreatedAt datetimeoffset NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT CK_AuditActor CHECK (ActorUserId IS NOT NULL OR ActorClientId IS NOT NULL)
);
GO
CREATE INDEX IX_Drafts_ProjectUpdated ON reqviora.ProjectDrafts(ProjectId,UpdatedAt DESC);
CREATE INDEX IX_Screens_ProjectStatus ON reqviora.Screens(ProjectId,SelectionStatus);
CREATE INDEX IX_Claims_ProjectStatus ON reqviora.CandidateClaims(ProjectId,ReviewStatus);
CREATE INDEX IX_Audit_ProjectTime ON reqviora.AuditEvents(ProjectId,CreatedAt DESC);
CREATE INDEX IX_Grant_ProjectRevision ON reqviora.McpGrants(ProjectId,RevisionId,ExpiresAt);
CREATE INDEX IX_Export_ProjectSource ON reqviora.ExportJobs(ProjectId,SourceRevisionId,Status);
GO
CREATE OR ALTER TRIGGER reqviora.TR_ApprovedRevision_NoMutation
ON reqviora.ApprovedRevisions
AFTER UPDATE, DELETE AS
BEGIN
  SET NOCOUNT ON;
  THROW 51000, 'Approved revisions are immutable. Branch a new draft instead.', 1;
END;
GO
/* Non-DDL invariants enforced by service + automated integration tests:
 1. Account project creation, draft and Owner membership committed atomically.
 2. ProjectId equality of any referenced source/feature/screen/action/revision.
 3. Last Owner cannot be removed; Reviewer cannot approve; SA cannot approve/read private content.
 4. Owner-only confirmation of AI suggestions; Editor changes Proposed until confirmed.
 5. One independent Approver for material edits; material edit definition/version evidence pending test catalog.
 6. Freeze selected group Viewer resources; no implicit new resources/revisions.
 7. Transactionally recheck validation-run source hash and rowversion on approval.
 8. Grant expiry, revocation, export download permission checked per request.
 9. Source/approval/export data retention and encryption depend on deployment policy.
 10. Keep old 7-stage draft migration reversible and old approved revisions readable.
*/
