import React from "react";
import { useMutation, gql } from '@apollo/client';
import "./CreatePost.css";

const CREATE_POST = gql`
  mutation createPost($input: CreatePostInput!) {
    createPost(input: $input) {
      post {
        headline
        body
        headerImageFile
      }
    }
  }
`;

const CreatePost = () => {

  const [createPost, { data, loading, error }] = useMutation(CREATE_POST, { refetchQueries: ["posts"] });

  if (loading) return 'Submitting...';
  if (error) return `Submission error! ${error.message}`;


  return (
    <div>
      <span className="create-post-header">Create Post</span>
      <form
        className={loading ? "locked" : undefined}
        onSubmit={event => {
          event.preventDefault();
          const fd = new FormData(event.target);
          const headline = fd.get("headline");
          const body = fd.get("body");
          const headerImageFile = fd.get("headerImageFile");
          createPost({
            variables: {
              input: {
                post: {
                  headline,
                  body,
                  headerImageFile
                }
              }
            }
          });
        }}
      >
        <label htmlFor="headline"> Headline</label>
        <input type="text" id="headline" name="headline" required />

        <label htmlFor="body">Body</label>
        <textarea id="body" name="body" required />

        <label>Header Image</label>

        <label
          className="input"
          htmlFor="headerImageFile"
          id="headerImageFile_label"
        >
          <button type="button" className="select-file">
            <input
              disabled
              id="headerImageFile_filename"
              defaultValue="Select File"
            />
          </button>
          <input
            type="file"
            id="headerImageFile"
            name="headerImageFile"
            accept="image/*"
            required
            onChange={event => {
              const filename =
                event.target.files.length > 0
                  ? event.target.files[0].name
                  : "";
              document.getElementById(
                `${event.target.id}_filename`
              ).value = filename;
            }}
          />
        </label>

        <button
          type="submit"
          className="spinner"
        >
          Submit
        </button>
      </form>
      {error && <p>Error :( Please try again</p>}
    </div>
  );
};

export default CreatePost;
