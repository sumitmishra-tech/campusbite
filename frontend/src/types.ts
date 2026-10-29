export type Category='All'|'Snacks'|'Meals'|'Drinks'|'Quick Bites';
export type Food={id:string;name:string;description:string;price:number;category:Exclude<Category,'All'>;image:string;time:string;available:boolean;tag?:string};
export type CartLine={food:Food;quantity:number};
