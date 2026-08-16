-- The SSR `navneobjekttype` values a rule version admits as peaks — e.g. Fjell, Topp,
-- Berg, Haug, Ås (ADR-0012 §3). A child table rather than a delimited column so the
-- rule stays queryable: "which types did version 1.0 include?" is a join, not a parse.
CREATE TABLE [ref].PeakRuleObjectType
(
    PeakRuleVersion varchar(20)     NOT NULL,
    NavneobjektType nvarchar(60)    NOT NULL,

    CONSTRAINT PK_ref_PeakRuleObjectType PRIMARY KEY CLUSTERED (PeakRuleVersion, NavneobjektType),
    CONSTRAINT FK_ref_PeakRuleObjectType_PeakRule FOREIGN KEY (PeakRuleVersion) REFERENCES [ref].PeakRule ([Version]) ON DELETE CASCADE
);
