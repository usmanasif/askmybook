import { useEffect, useState } from 'react'
import axios from 'axios'

import book from './book.png'
import './App.css'


const App = () => {
  // const ANSWER = 'The Minimalist Entrepreneur is a book about how to start and grow a business with less stress and fewer resources. It covers topics like how to choose what business to start, how to build and sell your product, and how to manage your time and money.'
  const question_id = null

  const [question, setQuestion] = useState('hello')
  const [answer, setAnswer] = useState('')
  const [letterIndex, setLetterIndex] = useState(0)
  const [loading, setLoading] = useState(false)
  let flag = false

  useEffect(() => {
    let intervalId = null
    if (letterIndex < answer.length) {
      intervalId = setInterval(() => {
        setLetterIndex(letterIndex + 1)
      }, 40)
    } else {
      clearInterval(intervalId)
    }
    return () => clearInterval(intervalId)
  }, [answer, letterIndex])

  useEffect(() => {
    if (flag) {
      return
    } else {
      flag = true
      const questionId = window.location.pathname.split('/')[2]
      
      if(typeof questionId !== 'undefined')
      fetchAnswer(questionId, null)
      
      return () => {
        if ('speechSynthesis' in window) {
          speechSynthesis.cancel()
        }
      }
    }
  }, [])

  const handleChange = ({target}) => {
    setQuestion(target.value)
  }

  const answerHanlder = () => {
    setLoading(true)
    fetchAnswer(null, question)
  }

  const fetchAnswer = (id, question) => {
    axios.post('http://localhost:3001/api/v1/questions', {
      id: id,
      title: question
    })
      .then(({data}) => {
        window.history.pushState({}, '', `/question/${data.id}`)
        setQuestion(data.question)
        data.question.length ? setAnswer(data.answer) : alert('Please ask a question!')
        setLoading(false)
        speechHanlder(data.answer)
      })
      .catch(err => {
        alert(err)
      })
  }

  const speechHanlder = answer => {
    if ('speechSynthesis' in window) {
      const utterance = new SpeechSynthesisUtterance(answer)
      utterance.rate = 0.9
      window.speechSynthesis.speak(utterance)
    }
  }

  const askQuestion = () => {
    setAnswer('')
    speechSynthesis.cancel()
    setLetterIndex(0)
  }

  return <div className='App'>
    <img src={book} className='book' alt='logo' />
    <h1 className='title'>Ask My Book</h1>
    <p className='credits'>
      This is an experiment in using AI to make my book's content more accessible. Ask a question and AI will answer it in real-time:
    </p>
    <textarea
      value={question}
      placeholder='Ask a question'
      onChange={handleChange}
      rows='4'
      className='question'
    />
    {answer.length === 0 ? 
      <div className='buttons'>
        <button 
          className={'' + (loading && 'loading')}
          onClick={answerHanlder}
          disabled={loading}>
            {loading ? 'Asking...' : 'Ask question'}
          </button>
        <button className='lucky' onClick={answerHanlder}>I'm feeling lucky</button>
      </div>
      : 
      <p className='answer'>
        <strong>Answer:</strong>
        <span> {answer.slice(0, letterIndex)} </span>
        {letterIndex === answer.length && 
          <button 
            className='other-question'
            onClick={askQuestion}
          >
            Ask another question
          </button>
        }
      </p>
    }
  </div>
}

export default App
