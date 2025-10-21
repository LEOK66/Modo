# Coding Guidelines

## Frontend: Swift & SwiftUI

**Guideline:** [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and [Apple's Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

**Why Chosen:**
- Official Swift.org guidelines ensure code consistency with Apple's ecosystem and standard library conventions
- Emphasizes clarity at the point of use, making code self-documenting and easier for team members to understand
- HIG ensures UI/UX consistency with native iOS patterns, critical for Modo's "seamless iOS integration" philosophy

**Enforcement:**
- **SwiftLint:** Integrated into Xcode build process to automatically flag violations (runs on every build)
- **Configuration:** `.swiftlint.yml` in repository root with rules for line length (120 chars), force unwrapping warnings, and naming conventions
- **Pull Request Reviews:** At least one team member must review Swift code before merging, checking for guideline adherence
- **Pre-commit Hook:** Optional Git hook runs SwiftLint before allowing commits

## Backend: TypeScript & Node.js

**Guideline:** [TypeScript Handbook - Do's and Don'ts](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html) and [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)

**Why Chosen:**
- TypeScript Handbook provides best practices for type safety, reducing runtime errors in Firebase Cloud Functions
- Airbnb guide is industry-standard with comprehensive rules for modern JavaScript/TypeScript, widely adopted and well-documented
- Strong emphasis on readability and consistency, important for 2-person backend team collaboration

**Enforcement:**
- **ESLint:** Configured with `@typescript-eslint` plugin and Airbnb preset in `.eslintrc.json`
- **Prettier:** Auto-formatting on save in VS Code ensures consistent code style (semicolons, quotes, indentation)
- **GitHub Actions CI:** ESLint runs on every push/PR; build fails if linting errors exist
- **Pull Request Reviews:** Backend code requires approval from the other backend developer, checking for type safety and code clarity
- **Pre-commit Hook:** Husky + lint-staged automatically runs ESLint and Prettier before commits

## General Practices

**Code Review Requirements:**
- All code must pass automated linting before PR can be merged
- PRs require at least 1 approval from another team member
- Reviewers check for: guideline compliance, test coverage, clear variable names, and proper error handling

**Documentation Standards:**
- Swift: Use DocC-style comments (`///`) for public APIs
- TypeScript: Use JSDoc comments for all exported functions
- Complex logic requires inline comments explaining the "why," not just the "what"
