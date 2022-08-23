import React from 'react'
import { render, fireEvent } from '@testing-library/react'
import App from './App'
// import axios from '../__mocks__/axios';

// axios.__setMockResponse({
//   status: 200,
//   data: {
//     answer: 'The Minimalist Entrepreneur is a book about how to start and grow a business with less stress and fewer resources.',
//   },
// });

describe('App component', () => {
  test('renders App component', () => {
    const { container } = render(<App />)
    expect(container).toMatchSnapshot()
  })

  test('renders initial component', () => {
    const { asFragment } = render(<App />)
    expect(asFragment()).toMatchSnapshot()
  })

  it('renders the title and buttons', () => {
    const { getByText } = render(<App />)

    expect(getByText('Ask My Book')).toBeInTheDocument()
    expect(getByText('Ask question')).toBeInTheDocument()
    expect(getByText("I'm feeling lucky")).toBeInTheDocument()
  })

  it('updates the question when textarea value changes', () => {
    const { getByPlaceholderText } = render(<App />)
    const question = getByPlaceholderText('Ask a question')

    fireEvent.change(question, { target: { value: 'What is your name?' } })
    expect(question.value).toBe('What is your name?')
  })

  // it('shows answer when ask question button is clicked', () => {
  //   const { getByText, getByPlaceholderText } = render(<App />)
  //   const question = getByPlaceholderText('Ask a question')
  //   const askButton = getByText('Ask question')

  //   fireEvent.change(question, { target: { value: 'What is your name?' } })
  //   fireEvent.click(askButton)
  //   expect(getByText('Answer:')).toBeInTheDocument()
  // })
})