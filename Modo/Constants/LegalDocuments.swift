import Foundation

/// Legal documents content for the app
enum LegalDocuments {
    
    // MARK: - Terms of Service
    static var termsOfService: String {
        """
TERMS OF SERVICE

Last Updated: \(formatDate(Date()))

1. ACCEPTANCE OF TERMS

By accessing or using the MODO application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you disagree with any part of these terms, then you may not access the App.

2. DESCRIPTION OF SERVICE

MODO is a health and wellness application that provides users with tools to track tasks, fitness activities, diet, and personal goals. The App may use artificial intelligence to provide personalized recommendations and insights.

3. USER ACCOUNT

3.1. You must create an account to use certain features of the App. You are responsible for maintaining the confidentiality of your account credentials.

3.2. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate, current, and complete.

3.3. You are responsible for all activities that occur under your account.

4. USER CONDUCT

4.1. You agree not to use the App in any way that:
   - Violates any applicable law or regulation
   - Infringes upon the rights of others
   - Is harmful, threatening, abusive, or offensive
   - Interferes with or disrupts the App or servers

4.2. You agree not to attempt to gain unauthorized access to the App or its related systems.

5. HEALTH INFORMATION

5.1. The App may collect health-related information, including but not limited to fitness data, dietary information, and health metrics.

5.2. This information is for informational purposes only and is not intended to diagnose, treat, cure, or prevent any disease.

5.3. Always consult with a qualified healthcare provider before making any changes to your diet, exercise routine, or health regimen.

6. INTELLECTUAL PROPERTY

6.1. The App and its original content, features, and functionality are owned by MODO and are protected by international copyright, trademark, and other intellectual property laws.

6.2. You may not reproduce, distribute, modify, or create derivative works of the App without prior written permission.

7. PRIVACY

Your use of the App is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices.

8. DISCLAIMER OF WARRANTIES

8.1. The App is provided "as is" and "as available" without any warranties of any kind, either express or implied.

8.2. MODO does not warrant that the App will be uninterrupted, secure, or error-free.

9. LIMITATION OF LIABILITY

9.1. To the maximum extent permitted by law, MODO shall not be liable for any indirect, incidental, special, consequential, or punitive damages.

9.2. MODO's total liability shall not exceed the amount you paid to use the App, if any.

10. TERMINATION

10.1. We may terminate or suspend your account and access to the App immediately, without prior notice, for any reason, including breach of these Terms.

10.2. Upon termination, your right to use the App will cease immediately.

11. CHANGES TO TERMS

11.1. We reserve the right to modify these Terms at any time. We will notify users of any material changes.

11.2. Your continued use of the App after any changes constitutes acceptance of the new Terms.

12. GOVERNING LAW

These Terms shall be governed by and construed in accordance with the laws of the jurisdiction in which MODO operates, without regard to its conflict of law provisions.

13. CONTACT INFORMATION

If you have any questions about these Terms, please contact us through the App's support features.

14. ACKNOWLEDGMENT

By using the App, you acknowledge that you have read these Terms and agree to be bound by them.
"""
    }
    
    // MARK: - Privacy Policy
    static var privacyPolicy: String {
        """
PRIVACY POLICY

Last Updated: \(formatDate(Date()))

1. INTRODUCTION

MODO ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application ("App").

2. INFORMATION WE COLLECT

2.1. Information You Provide:
   - Account information (email, password)
   - Profile information (name, avatar, age, height, weight)
   - Health and fitness data (tasks, exercises, diet entries)
   - Goals and preferences

2.2. Automatically Collected Information:
   - Device information (device type, operating system)
   - Usage data (features used, interaction patterns)
   - Location data (if permitted)

2.3. Third-Party Information:
   - Authentication information from Apple Sign-In or Google Sign-In
   - Health data from HealthKit (if integrated)

3. HOW WE USE YOUR INFORMATION

3.1. We use the information we collect to:
   - Provide and maintain the App
   - Personalize your experience
   - Process your requests and transactions
   - Send you notifications and updates
   - Improve the App's features and functionality
   - Analyze usage patterns and trends
   - Provide customer support

3.2. AI-Powered Features:
   - We may use artificial intelligence to analyze your data and provide personalized recommendations
   - Your data may be processed by AI services to generate insights and suggestions

4. DATA STORAGE AND SECURITY

4.1. Your data is stored securely using Firebase, which employs industry-standard security measures.

4.2. We implement appropriate technical and organizational measures to protect your personal information.

4.3. However, no method of transmission over the Internet or electronic storage is 100% secure.

5. DATA SHARING AND DISCLOSURE

5.1. We do not sell your personal information to third parties.

5.2. We may share your information in the following circumstances:
   - With service providers who assist us in operating the App
   - When required by law or legal process
   - To protect our rights and the safety of our users
   - In connection with a business transfer or merger

5.3. Aggregated or anonymized data may be used for analytics and improvement purposes.

6. THIRD-PARTY SERVICES

6.1. The App may contain links to third-party services. We are not responsible for the privacy practices of these services.

6.2. We use the following third-party services:
   - Firebase (authentication and database)
   - Google Sign-In
   - Apple Sign-In
   - OpenAI (for AI features, if applicable)

7. YOUR RIGHTS AND CHOICES

7.1. You have the right to:
   - Access your personal information
   - Correct inaccurate information
   - Request deletion of your information
   - Opt-out of certain data collection
   - Export your data

7.2. You can manage your privacy settings through the App's settings menu.

8. CHILDREN'S PRIVACY

8.1. The App is not intended for children under the age of 13.

8.2. We do not knowingly collect personal information from children under 13.

9. DATA RETENTION

9.1. We retain your personal information for as long as necessary to provide the App and fulfill the purposes outlined in this policy.

9.2. You may request deletion of your account and associated data at any time.

10. INTERNATIONAL DATA TRANSFERS

10.1. Your information may be transferred to and processed in countries other than your country of residence.

10.2. We ensure that appropriate safeguards are in place to protect your information.

11. CALIFORNIA PRIVACY RIGHTS

11.1. If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA).

11.2. You may request information about the categories of personal information we collect and how we use it.

12. CHANGES TO THIS PRIVACY POLICY

12.1. We may update this Privacy Policy from time to time.

12.2. We will notify you of any material changes by posting the new policy in the App.

12.3. Your continued use of the App after changes constitutes acceptance of the updated policy.

13. CONTACT US

If you have any questions about this Privacy Policy or our data practices, please contact us through the App's support features.

14. CONSENT

By using the App, you consent to the collection and use of information in accordance with this Privacy Policy.
"""
    }
    
    // MARK: - Helper Method
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

