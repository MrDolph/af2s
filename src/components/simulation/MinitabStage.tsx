'use client';
import type { ReactNode } from 'react';
import { SimulationStage } from './SimulationStage';
import './minitab-classroom.css';

export function MinitabStage({children,className=''}:{children:ReactNode;className?:string}) {
  return <SimulationStage className={`af-minitab-stage ${className}`}>{children}</SimulationStage>;
}
