import React from 'react';
import { useQuery, gql } from '@apollo/client';
import Post from './Post';

const GET_POSTS = gql`
  query posts {
    posts(first: 50) {
    nodes {
      id
      headline
      headerImageFile
    }
  }
}
`;


const Posts = () => {

  const { loading, error, data } = useQuery(GET_POSTS);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error : {error.message}</p>;

  return data.posts.nodes.map(post => Post(post));
}

export default Posts;