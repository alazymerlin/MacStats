 // swift-tools-version: 5.9
 import PackageDescription
 
 let package = Package(
     name: "MacStats",
     platforms: [
         .macOS(.v14),
     ],
     dependencies: [],
     targets: [
         .executableTarget(
             name: "MacStats",
             dependencies: [],
             path: "Sources/MacStats"
         ),
     ]
 )
