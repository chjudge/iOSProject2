//
//  PCView.swift
//  Project2
//
//  Created by Heston Suorsa on 11/15/22.
//

import SwiftUI
import PokemonAPI


struct PCView: View {
    
    @ObservedObject var PCVM = PCViewModel.shared
    
    var body: some View {
        NavigationView {
            VStack {
                List(PCVM.pokemon, id: \.id) { pkm in
                    NavigationLink(destination: PokemonDetailView(pokemon:pkm, dimensions: 120)) {
                        PokemonView(pokemon: pkm, dimensions: 120)
                    }
                }.onReceive(PCVM.firestore.$firestoreModels){ pokemon in
                    for pkm in pokemon{
                        if !PCVM.pokemon.contains(where: {$0.id! == pkm.pokemonID}){
                            Task{
                                await PCVM.fetchPokemon(id: pkm.pokemonID)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("My PC")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let query = PCVM.firestore.query()
                PCVM.firestore.subscribe(to: query)
            }
            .onDisappear {
                PCVM.firestore.unsubscribe()
            }
        }
        
        
    }
}

struct PCView_Previews: PreviewProvider {
    static var previews: some View {
        PCView()
    }
}
