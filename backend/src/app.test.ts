import {describe,it,expect} from 'vitest';import request from 'supertest';import {createApp} from './app.js';
const app=createApp();
describe('CampusBite API smoke tests',()=>{it('reports API health without making external service calls',async()=>{const response=await request(app).get('/api/health');expect(response.status).toBe(200);expect(response.body.ok).toBe(true);expect(response.body.service).toBe('CampusBite API')});it('requires authentication for private profile data',async()=>{const response=await request(app).get('/api/profile');expect(response.status).toBe(401)})});
