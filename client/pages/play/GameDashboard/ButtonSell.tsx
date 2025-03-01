import React from 'react'
import { useContractWrite } from 'wagmi'
import CONTRACT_ABI from '../../../data/abi.json'

const ButtonSell = () => {
  const farmerId = 1 // replace with actual farmerId

  const { data, isLoading, isSuccess, write } = useContractWrite({
    // @ts-ignore
    address: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    functionName: 'sellCrops',
    args: [farmerId, 10],
  })

  const sellHandler = () => {
    // @ts-ignore
    write('sellCrops')
  }

  return (
    <button onClick={sellHandler} disabled={isLoading}>Sell Crops</button>
  )
}

export default ButtonSell