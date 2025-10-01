import Factory

extension Container {
    var orientationManager: Factory<OrientationManager> {
        self { OrientationManagerImpl() }
            .singleton
    }
    
    var cameraManager: Factory<CameraManager> {
        self { CameraManagerImpl(orientationManager: self.orientationManager()) }
            .singleton
    }
    
    var ghostCamViewModel: Factory<RetroCamViewModel> {
        self { RetroCamViewModel(cameraManager: self.cameraManager(), 
                                 orientationManager: self.orientationManager()) }
    }
}
