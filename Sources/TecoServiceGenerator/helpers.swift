enum ServiceContext {
    @TaskLocal
    static var objects: [String : APIObject] = [:]
}
