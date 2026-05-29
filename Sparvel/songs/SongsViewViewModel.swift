
internal import UniformTypeIdentifiers
import Combine

class SongsViewViewModel : ObservableObject {

    @Published private(set) var uiState: SongsViewState = .NoData
    
    private let repository = MediaRepository()
    private var repositoryStateSubscriber: AnyCancellable?
    
    init() {
        queryCachedSongs()
    }

    func onIntent(intent: SongsIntent) {
        switch intent {
        case .LoadSongs(let urls):
            Task {
                setLoadingState()
                await repository.addMusicFiles(urls: urls)
            }
        case .RequestErrorState:
            setErrorState()
        }
    }
    
    private func queryCachedSongs() {
        repositoryStateSubscriber = repository.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.observeState(state: newState)
            }
    }
    
    private func observeState(state: MediaRepository.MediaState) {
        switch(state) {
            
        case .Loaded(let songs):
            setLoadedState(songs: songs)
        case .Error:
            setErrorState()
        case .Idle:
            setNoDataState()
        }
    }

    private func setErrorState() {
        uiState = .Error(
            "An error happened when loading data. Please, try again later"
        )
    }
    
    private func setNoDataState() {
        uiState = .NoData
    }

    private func setLoadingState() {
        uiState = .Loading
    }
    
    private func setLoadedState(songs: [Song]) {
        uiState = .Data(LoadedSongsViewState(songs: songs))
    }
}
