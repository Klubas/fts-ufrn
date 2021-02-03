
searchAcervo = async (searchQuery, searchType) => {

    removeDados()

    const url = currentLocation + '/busca_acervo/';
    const settings = {
        method: 'POST',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify(
                {
                    query: searchQuery,
                    type: searchType
                }
            )
    };
    try {
        const fetchResponse = await fetch(url, settings);
        const data = await fetchResponse.json();
        await exibeDados(data.Response)
    } catch (e) {
        await console.log(e)
    }

};

function removeDados() {

    const buttonFTS = document.getElementById('buttonFTS')
    buttonFTS.setAttribute('disabled', 'true')

    const buttonNormal = document.getElementById('buttonNormal')
    buttonNormal.setAttribute('disabled', 'true')

    try {
        const container = document.getElementById('container')
        container.remove()

        const pText = document.getElementById('pText')
        pText.remove()


    } catch (err){

    }
}

function exibeDados(data) {

    const results = document.getElementById('results')
    const container = document.createElement('div')
    container.setAttribute('class', 'container')
    container.setAttribute('id', 'container')
    results.appendChild(container)

    delta = data[0]
    quantidade = data[1]
    obras = data.slice(2)

    const search = document.getElementById('search')
    const pText = document.createElement('p')
    pText.setAttribute('id', 'pText')

    textNode = document.createTextNode(quantidade + ' resultados em ' + delta + 'ms.')
    pText.appendChild(textNode)
    search.appendChild(pText)

    obras.forEach((obra) => {

        obra = obra.results
        obra = obra.substring(0, 300)

        const card = document.createElement('div')
        card.setAttribute('class', 'card')

        const h1 = document.createElement('h1')
        h1.textContent = obra

        container.appendChild(card)

        card.appendChild(h1)
    })

    const buttonFTS = document.getElementById('buttonFTS')
    buttonFTS.removeAttribute("disabled")

    const buttonNormal = document.getElementById('buttonNormal')
    buttonNormal.removeAttribute("disabled")

};


const buttonFTS = document.getElementById('buttonFTS')
const buttonNormal = document.getElementById('buttonNormal')
const searchField = document.getElementById('searchField')

const currentLocation = window.location.href
console.log(currentLocation)

buttonFTS.addEventListener('click',
    function(){searchAcervo(searchField.value,'FTS')}
)

buttonNormal.addEventListener('click',
    function(){searchAcervo(searchField.value,'Normal')}
)

