import XCTest
import Foundation
@testable import PrivarionCore

final class SecurityProfileManagerTests: XCTestCase {
    
    var profileManager: SecurityProfileManager!
    
    override func setUp() {
        super.setUp()
        profileManager = SecurityProfileManager.shared
    }
    
    override func tearDown() {
        // Clean up any profiles created during tests
        let profiles = profileManager.getAllProfiles()
        for profile in profiles {
            try? profileManager.deleteProfile(profileID: profile.id)
        }
        profileManager = nil
        super.tearDown()
    }
    
    // MARK: - Profile Creation Tests
    
    func testCreateProfile_ValidProfile_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Test Security Profile",
            description: "A test profile for unit testing",
            enforcementLevel: .strict,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(
                evaluationTimeout: 5.0,
                policyUpdateTimeout: 10.0,
                healthCheckInterval: 60.0
            ),
            auditSettings: SecurityProfile.AuditSettings(
                enableAuditLogging: true,
                logLevel: .info,
                includeStackTrace: false,
                maxLogFileSize: 10485760, // 10MB
                logRetentionDays: 30
            )
        )
        
        // When
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            
            // Then
            XCTAssertNotNil(profile.id)
            XCTAssertEqual(profile.name, "Test Security Profile")
            XCTAssertEqual(profile.enforcementLevel, .strict)
            XCTAssertEqual(profile.status, .inactive)
            XCTAssertTrue(profile.isEnabled)
            
            let allProfiles = profileManager.getAllProfiles()
            XCTAssertEqual(allProfiles.count, 1)
            XCTAssertEqual(allProfiles.first?.id, profile.id)
        } catch {
            XCTFail("Creating valid profile should not throw error: \(error)")
        }
    }
    
    func testCreateProfile_DuplicateName_ShouldFail() {
        // Given
        let profileConfig1 = SecurityProfile.ProfileConfiguration(
            name: "Duplicate Profile Name",
            description: "First profile",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        let profileConfig2 = SecurityProfile.ProfileConfiguration(
            name: "Duplicate Profile Name", // Same name
            description: "Second profile",
            enforcementLevel: .strict,
            defaultAction: .deny,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        // When
        do {
            let profile1 = try profileManager.createProfile(config: profileConfig1)
            XCTAssertNotNil(profile1)
            
            // This should fail
            let _ = try profileManager.createProfile(config: profileConfig2)
            XCTFail("Creating profile with duplicate name should throw error")
        } catch {
            // Then
            XCTAssertTrue(error is SecurityProfileManager.ProfileError)
            let allProfiles = profileManager.getAllProfiles()
            XCTAssertEqual(allProfiles.count, 1)
            XCTAssertEqual(allProfiles.first?.description, "First profile")
        }
    }
    
    func testCreateProfile_EmptyName_ShouldFail() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "", // Empty name
            description: "Profile with empty name",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        // When & Then
        do {
            let _ = try profileManager.createProfile(config: profileConfig)
            XCTFail("Creating profile with empty name should throw error")
        } catch {
            XCTAssertTrue(error is SecurityProfileManager.ProfileError)
        }
    }
    
    // MARK: - Profile Management Tests
    
    func testGetProfile_ExistingProfile_ShouldReturnProfile() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Test Profile",
            description: "Test description",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let createdProfile = try profileManager.createProfile(config: profileConfig)
            
            // When
            let retrievedProfile = profileManager.getProfile(profileID: createdProfile.id)
            
            // Then
            XCTAssertNotNil(retrievedProfile)
            XCTAssertEqual(retrievedProfile?.id, createdProfile.id)
            XCTAssertEqual(retrievedProfile?.name, "Test Profile")
            XCTAssertEqual(retrievedProfile?.description, "Test description")
        } catch {
            XCTFail("Profile management should not throw error: \(error)")
        }
    }
    
    func testGetProfile_NonExistentProfile_ShouldReturnNil() {
        // Given
        let nonExistentID = UUID().uuidString
        
        // When
        let profile = profileManager.getProfile(profileID: nonExistentID)
        
        // Then
        XCTAssertNil(profile)
    }
    
    func testUpdateProfile_ExistingProfile_ShouldSucceed() {
        // Given
        let initialConfig = SecurityProfile.ProfileConfiguration(
            name: "Initial Profile",
            description: "Initial description",
            enforcementLevel: .lenient,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        let updatedConfig = SecurityProfile.ProfileConfiguration(
            name: "Updated Profile",
            description: "Updated description",
            enforcementLevel: .strict,
            defaultAction: .deny,
            timeoutSettings: SecurityProfile.TimeoutSettings(
                evaluationTimeout: 10.0,
                policyUpdateTimeout: 20.0,
                healthCheckInterval: 120.0
            ),
            auditSettings: SecurityProfile.AuditSettings(
                enableAuditLogging: true,
                logLevel: .debug,
                includeStackTrace: true,
                maxLogFileSize: 20971520, // 20MB
                logRetentionDays: 60
            )
        )
        
        do {
            let profile = try profileManager.createProfile(config: initialConfig)
            
            // When
            try profileManager.updateProfile(profileID: profile.id, config: updatedConfig)
            
            // Then
            let updatedProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertNotNil(updatedProfile)
            XCTAssertEqual(updatedProfile?.name, "Updated Profile")
            XCTAssertEqual(updatedProfile?.description, "Updated description")
            XCTAssertEqual(updatedProfile?.enforcementLevel, .strict)
            XCTAssertEqual(updatedProfile?.defaultAction, .deny)
        } catch {
            XCTFail("Profile update should not throw error: \(error)")
        }
    }
    
    func testDeleteProfile_ExistingProfile_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile to Delete",
            description: "This profile will be deleted",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            XCTAssertEqual(profileManager.getAllProfiles().count, 1)
            
            // When
            try profileManager.deleteProfile(profileID: profile.id)
            
            // Then
            XCTAssertEqual(profileManager.getAllProfiles().count, 0)
            XCTAssertNil(profileManager.getProfile(profileID: profile.id))
        } catch {
            XCTFail("Profile deletion should not throw error: \(error)")
        }
    }
    
    func testDeleteProfile_NonExistentProfile_ShouldFail() {
        // Given
        let nonExistentID = UUID().uuidString
        
        // When & Then
        do {
            try profileManager.deleteProfile(profileID: nonExistentID)
            XCTFail("Deleting non-existent profile should throw error")
        } catch {
            XCTAssertTrue(error is SecurityProfileManager.ProfileError)
        }
    }
    
    // MARK: - Profile Activation Tests
    
    func testActivateProfile_InactiveProfile_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile to Activate",
            description: "This profile will be activated",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            XCTAssertEqual(profile.status, .inactive)
            
            // When
            try profileManager.activateProfile(profileID: profile.id)
            
            // Then
            let activatedProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertEqual(activatedProfile?.status, .active)
            XCTAssertEqual(profileManager.getActiveProfile()?.id, profile.id)
        } catch {
            XCTFail("Profile activation should not throw error: \(error)")
        }
    }
    
    func testActivateProfile_AlreadyActiveProfile_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Already Active Profile",
            description: "This profile is already active",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            try profileManager.activateProfile(profileID: profile.id)
            XCTAssertEqual(profile.status, .active)
            
            // When - Try to activate again
            try profileManager.activateProfile(profileID: profile.id)
            
            // Then - Should still be active
            let activeProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertEqual(activeProfile?.status, .active)
        } catch {
            XCTFail("Re-activating active profile should not throw error: \(error)")
        }
    }
    
    func testDeactivateProfile_ActiveProfile_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile to Deactivate",
            description: "This profile will be deactivated",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            try profileManager.activateProfile(profileID: profile.id)
            XCTAssertEqual(profileManager.getActiveProfile()?.id, profile.id)
            
            // When
            try profileManager.deactivateProfile(profileID: profile.id)
            
            // Then
            let deactivatedProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertEqual(deactivatedProfile?.status, .inactive)
            XCTAssertNil(profileManager.getActiveProfile())
        } catch {
            XCTFail("Profile deactivation should not throw error: \(error)")
        }
    }
    
    // MARK: - Policy Management Tests
    
    func testAddPolicy_ValidPolicy_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile with Policies",
            description: "Profile for testing policy management",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        let policy = SecurityProfile.Policy(
            id: UUID().uuidString,
            name: "Test Network Policy",
            description: "Policy for testing network access",
            type: .network,
            conditions: [
                SecurityProfile.PolicyCondition(
                    field: "destination_port",
                    operatorType: .equals,
                    value: "80"
                )
            ],
            action: .deny,
            enabled: true,
            priority: 100
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            
            // When
            try profileManager.addPolicy(profileID: profile.id, policy: policy)
            
            // Then
            let updatedProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertEqual(updatedProfile?.policies.count, 1)
            XCTAssertEqual(updatedProfile?.policies.first?.id, policy.id)
            XCTAssertEqual(updatedProfile?.policies.first?.name, "Test Network Policy")
        } catch {
            XCTFail("Adding policy should not throw error: \(error)")
        }
    }
    
    func testRemovePolicy_ExistingPolicy_ShouldSucceed() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile with Policy to Remove",
            description: "Profile for testing policy removal",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        let policy = SecurityProfile.Policy(
            id: UUID().uuidString,
            name: "Policy to Remove",
            description: "This policy will be removed",
            type: .fileSystem,
            conditions: [],
            action: .allow,
            enabled: true,
            priority: 50
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            try profileManager.addPolicy(profileID: profile.id, policy: policy)
            XCTAssertEqual(profileManager.getProfile(profileID: profile.id)?.policies.count, 1)
            
            // When
            try profileManager.removePolicy(profileID: profile.id, policyID: policy.id)
            
            // Then
            let updatedProfile = profileManager.getProfile(profileID: profile.id)
            XCTAssertEqual(updatedProfile?.policies.count, 0)
        } catch {
            XCTFail("Removing policy should not throw error: \(error)")
        }
    }
    
    // MARK: - Profile Statistics Tests
    
    func testGetProfileStatistics_ShouldReturnValidStats() {
        // Given
        let profileConfig = SecurityProfile.ProfileConfiguration(
            name: "Profile for Statistics",
            description: "Profile for testing statistics",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: SecurityProfile.TimeoutSettings(),
            auditSettings: SecurityProfile.AuditSettings()
        )
        
        do {
            let profile = try profileManager.createProfile(config: profileConfig)
            try profileManager.activateProfile(profileID: profile.id)
            
            // When
            let stats = try profileManager.getProfileStatistics(profileID: profile.id)
            
            // Then
            XCTAssertGreaterThanOrEqual(stats.totalEvaluations, 0)
            XCTAssertGreaterThanOrEqual(stats.allowedActions, 0)
            XCTAssertGreaterThanOrEqual(stats.deniedActions, 0)
            XCTAssertGreaterThanOrEqual(stats.averageEvaluationTime, 0)
        } catch {
            XCTFail("Getting profile statistics should not throw error: \(error)")
        }
    }
    
    // MARK: - Configuration Validation Tests
    
    func testProfileConfiguration_DefaultValues_ShouldInitialize() {
        // Given & When
        let timeoutSettings = SecurityProfile.TimeoutSettings()
        let auditSettings = SecurityProfile.AuditSettings()
        
        let config = SecurityProfile.ProfileConfiguration(
            name: "Default Config Profile",
            description: "Profile with default settings",
            enforcementLevel: .moderate,
            defaultAction: .allow,
            timeoutSettings: timeoutSettings,
            auditSettings: auditSettings
        )
        
        // Then
        XCTAssertEqual(config.name, "Default Config Profile")
        XCTAssertEqual(config.enforcementLevel, .moderate)
        XCTAssertEqual(config.defaultAction, .allow)
        XCTAssertEqual(timeoutSettings.evaluationTimeout, 5.0)
        XCTAssertEqual(timeoutSettings.policyUpdateTimeout, 10.0)
        XCTAssertEqual(timeoutSettings.healthCheckInterval, 60.0)
        XCTAssertEqual(auditSettings.enableAuditLogging, true)
        XCTAssertEqual(auditSettings.logLevel, .info)
        XCTAssertEqual(auditSettings.includeStackTrace, false)
    }
    
    func testPolicyCondition_AllOperatorTypes_ShouldWork() {
        // Given & When & Then
        let equalsCondition = SecurityProfile.PolicyCondition(
            field: "port",
            operatorType: .equals,
            value: "80"
        )
        XCTAssertEqual(equalsCondition.operatorType, .equals)
        
        let containsCondition = SecurityProfile.PolicyCondition(
            field: "path",
            operatorType: .contains,
            value: "/etc"
        )
        XCTAssertEqual(containsCondition.operatorType, .contains)
        
        let greaterThanCondition = SecurityProfile.PolicyCondition(
            field: "size",
            operatorType: .greaterThan,
            value: "1024"
        )
        XCTAssertEqual(greaterThanCondition.operatorType, .greaterThan)
        
        let regexCondition = SecurityProfile.PolicyCondition(
            field: "filename",
            operatorType: .regex,
            value: ".*\\.tmp$"
        )
        XCTAssertEqual(regexCondition.operatorType, .regex)
    }
    
    // MARK: - Performance Tests
    
    func testCreateProfile_Performance() {
        // Test that profile creation completes within reasonable time
        measure {
            for i in 0..<50 {
                let config = SecurityProfile.ProfileConfiguration(
                    name: "Performance Test Profile \(i)",
                    description: "Performance test profile",
                    enforcementLevel: .moderate,
                    defaultAction: .allow,
                    timeoutSettings: SecurityProfile.TimeoutSettings(),
                    auditSettings: SecurityProfile.AuditSettings()
                )
                
                do {
                    _ = try profileManager.createProfile(config: config)
                } catch {
                    // Ignore errors in performance test
                }
            }
        }
    }
    
    func testProfileLookup_Performance() {
        // Given - Create multiple profiles
        var profileIDs: [String] = []
        for i in 0..<100 {
            let config = SecurityProfile.ProfileConfiguration(
                name: "Lookup Test Profile \(i)",
                description: "Profile for lookup performance test",
                enforcementLevel: .moderate,
                defaultAction: .allow,
                timeoutSettings: SecurityProfile.TimeoutSettings(),
                auditSettings: SecurityProfile.AuditSettings()
            )
            
            do {
                let profile = try profileManager.createProfile(config: config)
                profileIDs.append(profile.id)
            } catch {
                // Ignore errors in setup
            }
        }
        
        // When - Test lookup performance
        measure {
            for profileID in profileIDs {
                _ = profileManager.getProfile(profileID: profileID)
            }
        }
    }
}
