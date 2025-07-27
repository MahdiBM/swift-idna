<p>
    <a href="https://github.com/MahdiBM/swift-idna/actions/workflows/tests.yml">
        <img
            src="https://img.shields.io/github/actions/workflow/status/MahdiBM/swift-idna/tests.yml?event=push&style=plastic&logo=github&label=tests&logoColor=%23ccc"
            alt="Unit Tests CI"
        >
    </a>
    <a href="https://swift.org">
        <img
            src="https://design.vapor.codes/images/swift60up.svg"
            alt="Swift 6.0+"
        >
    </a>
</p>

# swift-idna

A dependncy-free, multiplatform implementation of Punycode and IDNA (Internationalized Domain Names in Applications) as per [RFC 5891](https://datatracker.ietf.org/doc/html/rfc5891) and friends.

## Usage

Initialize `IDNA` with your preffered configuration, then use `toASCII(domainName:)` and `toUnicode(domainName:)`:

```swift
import SwiftIDNA

let idna = IDNA(configuration: .mostStrict)

/// Turn user input into a IDNA-compatible domain name using toASCII:
print(idna.toASCII(domainName: "新华网.中国"))
/// prints "xn--xkrr14bows.xn--fiqs8s"

/// Turn back a IDNA-compatible domain name to its Unicode representation using toUnicode:
print(idna.toUnicode(domainName: "xn--xkrr14bows.xn--fiqs8s"))
/// prints "新华网.中国"
```

Domain names are inherently case-insensitive, and they will be lowercased if they need to go through any conversions.

If they are short-circuted, they won't necesssarily be lowercased.

If you need consistent lowercased domain names, either use Swift's `String.lowercased()` after a `toASCII(domainName:)` call, or implement your own [ASCII-specific lowercasing function](https://github.com/search?q=repo:MahdiBM/swift-dns+ASCIIToLowercase&type=code).

## Implementation
This package uses Unicode 17's [IDNA test v2 suite](https://www.unicode.org/Public/idna/16.0.0/IdnaTestV2.txt) with ~6400 test cases to ensure full compatibility.

Runs each test case extensively so each test case might even result in 2-3-4-5 test runs.

The C code is all automatically generated using the 2 scripts in `utils/`:
* `IDNAMappingTableGenerator.swift` generates the [IDNA mapping lookup table](https://www.unicode.org/Public/idna/17.0.0/IdnaMappingTable.txt).
* `IDNATestV2Generator.swift` generates the [IDNA test v2 suite](https://www.unicode.org/Public/idna/17.0.0/IdnaTestV2.txt) cases to use in tests to ensure full compatibility.

#### Current supported [IDNA flags](https://www.unicode.org/reports/tr46/#Processing):
- [x] checkHyphens
- [ ] checkBidi
- [ ] checkJoiners
- [x] useSTD3ASCIIRules
- [ ] transitionalProcessing (deprecated, Unicode discourages support for this flag although it's trivial to support)
- [x] verifyDnsLength
- [x] ignoreInvalidPunycode
- [ ] replaceBadCharacters
  * This last one is not a strict part of IDNA, and is only "recommended" to implement.

## How To Add swift-idna To Your Project

To use the `swift-idna` library in a SwiftPM project,
add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/mahdibm/swift-idna.git", branch: "main"),
```

Include `SwiftIDNA` as a dependency for your targets:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "SwiftIDNA", package: "swift-idna"),
]),
```

Finally, add `import SwiftIDNA` to your source code.

## Acknowledgments

This package was initially a part of [swift-dns](https://github.com/MahdiBM/swift-dns) which I decided to decouple from that project.
