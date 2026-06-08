
import Observation
internal import UniformTypeIdentifiers

@Observable
class SongsViewViewModel {

    private(set) var uiState: SongsViewState = .NoData
    private let repository = MediaRepository()
    
    private var loadedSongs: [Song] = []
    
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
        case .FilterSongs(let query):
            filterSongs(query: query)
        case .RequestErrorState:
            setErrorState()
        }
    }
    
    private func queryCachedSongs() {
        withObservationTracking {
            observeState(state: repository.state)
        } onChange: {
            Task { @MainActor in
                self.queryCachedSongs()
            }
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
    
    // TODO: filter songs with missclicks and diactric symbols + permutations
    private func filterSongs(query: String) {
        
        var filteredSongs: [Song]
        if query.isEmpty {
            filteredSongs = loadedSongs
        } else {
            filteredSongs = loadedSongs.filter { song in
                song.artist.contains(query) || song.title.contains(query)
            }
        }
        
        uiState = .Data(LoadedSongsViewState(songs: filteredSongs))
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
        loadedSongs = songs
        uiState = .Data(LoadedSongsViewState(songs: loadedSongs))
    }
}
